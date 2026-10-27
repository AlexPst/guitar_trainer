import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../engine/note_event.dart';
import 'note_event_source.dart';

/// [NoteEventSource] running in a background isolate so pitch and attack
/// analysis (several ms per mic chunk) never stalls UI frames.
///
/// Song time is still taken on the UI side when a chunk arrives and sent along
/// with it, so timing is the same as with the synchronous source.
class IsolateNoteEventSource {
  IsolateNoteEventSource._(
    this._isolate,
    this._toWorker,
    this._fromWorker,
    this.delay,
  );

  static Future<IsolateNoteEventSource> spawn({
    required int sampleRate,
    double minLevelDbfs = -50,
  }) async {
    final fromWorker = ReceivePort();
    final isolate = await Isolate.spawn(_worker, (
      fromWorker.sendPort,
      sampleRate,
      minLevelDbfs,
    ), debugName: 'note-analysis');
    final messages = fromWorker.asBroadcastStream();
    final toWorker = await messages.first as SendPort;
    final delay = NoteEventSource(sampleRate: sampleRate).delay;
    final source = IsolateNoteEventSource._(
      isolate,
      toWorker,
      fromWorker,
      delay,
    );
    messages.listen((m) {
      if (m is List<NoteEvent> && m.isNotEmpty) source._events.add(m);
    });
    return source;
  }

  final Isolate _isolate;
  final SendPort _toWorker;
  final ReceivePort _fromWorker;
  final _events = StreamController<List<NoteEvent>>.broadcast();

  /// See [NoteEventSource.delay].
  final double delay;

  /// Batches of events, in time order.
  Stream<List<NoteEvent>> get events => _events.stream;

  /// Sends a copy of [chunk] for analysis; see [NoteEventSource.add].
  void add(Float32List chunk, {required double songTime, double speed = 1}) {
    _toWorker.send((TransferableTypedData.fromList([chunk]), songTime, speed));
  }

  Future<void> dispose() async {
    _isolate.kill(priority: Isolate.immediate);
    _fromWorker.close();
    await _events.close();
  }
}

void _worker((SendPort, int, double) args) {
  final (reply, sampleRate, minLevelDbfs) = args;
  final source = NoteEventSource(
    sampleRate: sampleRate,
    minLevelDbfs: minLevelDbfs,
  );
  final inbox = ReceivePort();
  reply.send(inbox.sendPort);
  inbox.listen((message) {
    final (data, songTime, speed) =
        message as (TransferableTypedData, double, double);
    final chunk = data.materialize().asFloat32List();
    reply.send(source.add(chunk, songTime: songTime, speed: speed));
  });
}
