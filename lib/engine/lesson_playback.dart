import '../music/lesson.dart';
import 'metronome_scheduler.dart';
import 'song_clock.dart';

enum PlaybackPhase { ready, countIn, playing, paused, finished }

/// Start/pause/finish logic of a lesson on top of a [SongClock].
///
/// Song time is negative during the count-in and reaches 0 on the first beat.
class LessonPlayback {
  LessonPlayback(
    this.lesson, {
    SongClock? clock,
    this.countInBars = 1,
    this.tailSeconds = 1.0,
  }) : clock = clock ?? SongClock(),
       grid = BeatGrid(lesson.secondsPerBeat, lesson.timeSignature.beatsPerBar);

  final Lesson lesson;
  final SongClock clock;
  final BeatGrid grid;
  final int countInBars;

  /// Pause after the last note before the lesson counts as finished.
  final double tailSeconds;

  bool _started = false;
  bool _paused = false;
  bool _finished = false;

  int get countInBeats => countInBars * lesson.timeSignature.beatsPerBar;
  double get countInSeconds => countInBeats * lesson.secondsPerBeat;
  double get endTime => lesson.lengthInSeconds + tailSeconds;

  double get time => clock.time;
  double get speed => clock.speed;

  PlaybackPhase get phase {
    if (!_started) return PlaybackPhase.ready;
    if (_finished) return PlaybackPhase.finished;
    if (_paused) return PlaybackPhase.paused;
    return time < 0 ? PlaybackPhase.countIn : PlaybackPhase.playing;
  }

  /// 1-based count-in beat, or null outside the count-in.
  int? get countInBeat {
    final t = time;
    if (t >= 0 || !_started) return null;
    return ((t + countInSeconds) / lesson.secondsPerBeat).floor() + 1;
  }

  /// 0..1 through the notes (ignores count-in and tail).
  double get progress {
    final len = lesson.lengthInSeconds;
    return len <= 0 ? 0 : (time / len).clamp(0.0, 1.0);
  }

  void start() {
    _started = true;
    _paused = false;
    _finished = false;
    clock.start(-countInSeconds);
  }

  void pause() {
    if (phase case PlaybackPhase.countIn || PlaybackPhase.playing) {
      clock.pause();
      _paused = true;
    }
  }

  void resume() {
    if (phase != PlaybackPhase.paused) return;
    _paused = false;
    clock.resume();
  }

  set speed(double value) => clock.speed = value;

  /// Stops the clock once the end is reached. Returns true on that frame only.
  bool checkFinished() {
    if (_finished || !_started || _paused || time < endTime) return false;
    clock.pause();
    _finished = true;
    return true;
  }

  /// Last metronome beat: the bar line after the last note.
  int get lastBeatIndex {
    final bars = (lesson.lengthInBeats / grid.beatsPerBar).ceil();
    return bars * grid.beatsPerBar;
  }
}
