import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';

import 'level_meter.dart';

class MicPermissionDenied implements Exception {
  const MicPermissionDenied();
  @override
  String toString() => 'Нет доступа к микрофону';
}

/// Captures mono float32 PCM from the default input device.
class MicCapture {
  MicCapture({this.sampleRate = 44100});

  final int sampleRate;
  final _recorder = Recorder.instance;
  final _controller = StreamController<Float32List>.broadcast();
  StreamSubscription<AudioDataContainer>? _sub;

  /// Sample chunks. The buffer is reused by the plugin: copy it if you keep it.
  Stream<Float32List> get samples => _controller.stream;

  Future<void> start() async {
    if (Platform.isAndroid) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) throw const MicPermissionDenied();
    }
    await _recorder.init(
      format: PCMFormat.f32le,
      sampleRate: sampleRate,
      channels: RecorderChannels.mono,
      // Raw signal: no AGC / noise suppression that would distort the guitar.
      androidInputPreset: AndroidInputPreset.unprocessed,
    );
    _recorder.start();
    _sub = _recorder.uint8ListStream.listen(
      (data) => _controller.add(bytesToFloat32(data.rawData)),
    );
    _recorder.startStreamingData();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (_recorder.isInitialized) {
      _recorder.stopStreamingData();
      _recorder.stop();
      _recorder.deinit();
    }
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
