import 'package:guitar_trainer/engine/metronome_scheduler.dart';
import 'package:guitar_trainer/engine/song_clock.dart';
import 'package:guitar_trainer/music/lesson.dart';

/// Manually advanced clock.
class FakeTime {
  Duration now = Duration.zero;

  TimeSource get source =>
      () => now;

  double get seconds => now.inMicroseconds / 1e6;

  void advance(double seconds) =>
      now += Duration(microseconds: (seconds * 1e6).round());
}

/// Records when each click would actually sound, in real seconds.
class RecordingSink implements MetronomeSink {
  RecordingSink(this.time);

  final FakeTime time;
  double _anchorReal = 0;
  double _anchorSong = 0;
  double _speed = 1;

  /// (beat, real time it would play, real time it was scheduled).
  final played = <(Beat, double, double)>[];
  int cancels = 0;

  @override
  void anchor(double songTime, double speed) {
    _anchorReal = time.seconds;
    _anchorSong = songTime;
    _speed = speed;
  }

  @override
  void schedule(Beat beat) {
    final at = _anchorReal + (beat.time - _anchorSong) / _speed;
    played.add((beat, at, time.seconds));
  }

  @override
  void cancelPending() {
    cancels++;
    // Drop clicks that have not sounded yet, like the real metronome.
    played.removeWhere((p) => p.$2 > time.seconds);
  }
}

Lesson testLesson({double bpm = 60, int beats = 3}) => Lesson(
  id: 't',
  title: 'Тест',
  bpm: bpm,
  timeSignature: const TimeSignature(4, 4),
  notes: [
    for (var i = 0; i < beats; i++)
      TabNote(beat: i.toDouble(), string: 6 - i % 6, fret: i % 5, duration: 1),
  ],
);
