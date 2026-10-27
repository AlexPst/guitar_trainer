import 'dart:typed_data';

import '../engine/note_event.dart';
import 'onset_detector.dart';
import 'pitch_tracker.dart';

/// Turns microphone samples into [NoteEvent]s in song time.
///
/// Pitch comes from YIN on short, unsmoothed frames so a new note is not
/// masked by the previous one. Attacks come from [OnsetDetector] with
/// confirmation, which drops short clicks such as our own metronome.
///
/// Events are released in time order once every attack up to their time has
/// been decided, i.e. about [delay] seconds after they were heard.
class NoteEventSource {
  NoteEventSource({
    required this.sampleRate,
    OnsetDetector? onsets,
    PitchTracker? pitch,
  }) : _onsets =
           onsets ?? OnsetDetector(sampleRate: sampleRate, confirmAfter: 0.06),
       _pitch =
           pitch ??
           PitchTracker(
             sampleRate: sampleRate,
             windowSize: 2048,
             hopSize: 1024,
             minLevelDbfs: -50,
             smoothing: 1,
             dropAfterSilentFrames: 1,
           );

  final int sampleRate;
  final OnsetDetector _onsets;
  final PitchTracker _pitch;

  int _samples = 0;

  /// Not yet released: (sample position, event).
  final List<(int, NoteEvent)> _pending = [];

  /// How long events are held back, seconds.
  double get delay => _onsets.confirmAfter + 2 * _onsets.hopSize / sampleRate;

  /// Feeds a chunk. [songTime] is the song time of the chunk's last sample
  /// and [speed] the playback speed; they map sample positions to song time.
  List<NoteEvent> add(
    Float32List chunk, {
    required double songTime,
    double speed = 1,
  }) {
    _samples += chunk.length;
    double at(int sample) =>
        songTime - (_samples - sample) / sampleRate * speed;

    for (final t in _onsets.add(chunk)) {
      final sample = (t * sampleRate).round();
      _pending.add((sample, NoteEvent(at(sample), null, onset: true)));
    }
    // PitchTracker counts the same samples, so its positions match ours.
    for (final (sample, f) in _pitch.addTimed(chunk)) {
      if (f != null) _pending.add((sample, NoteEvent(at(sample), f)));
    }

    // Attacks are confirmed late; release only what can no longer change.
    final safe = _samples - (delay * sampleRate).round();
    _pending.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      return (b.$2.onset ? 1 : 0) - (a.$2.onset ? 1 : 0); // onset first
    });
    final out = <NoteEvent>[];
    while (_pending.isNotEmpty && _pending.first.$1 <= safe) {
      out.add(_pending.removeAt(0).$2);
    }
    return out;
  }

  void reset() {
    _samples = 0;
    _pending.clear();
    _onsets.reset();
    _pitch.reset();
  }
}
