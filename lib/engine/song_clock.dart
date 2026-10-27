/// Monotonic time source; injectable for tests.
typedef TimeSource = Duration Function();

TimeSource stopwatchTimeSource() {
  final sw = Stopwatch()..start();
  return () => sw.elapsed;
}

double _seconds(Duration d) =>
    d.inMicroseconds / Duration.microsecondsPerSecond;

/// Song position in seconds (lesson time at 100% tempo).
///
/// Derived from a monotonic clock, never accumulated from frame deltas, so it
/// does not drift. [speed] slows the song down: at 0.5 one real second
/// advances the song by half a second.
class SongClock {
  SongClock({TimeSource? now}) : _now = now ?? stopwatchTimeSource();

  static const minSpeed = 0.5;
  static const maxSpeed = 1.0;

  final TimeSource _now;
  double _anchorSong = 0;
  Duration _anchorReal = Duration.zero;
  bool _running = false;
  double _speed = 1;

  bool get isRunning => _running;
  double get speed => _speed;

  double get time => _running
      ? _anchorSong + _seconds(_now() - _anchorReal) * _speed
      : _anchorSong;

  void start([double from = 0]) {
    _anchorSong = from;
    _anchorReal = _now();
    _running = true;
  }

  void pause() {
    if (!_running) return;
    _anchorSong = time;
    _running = false;
  }

  void resume() {
    if (_running) return;
    _anchorReal = _now();
    _running = true;
  }

  void seek(double songTime) {
    _anchorSong = songTime;
    _anchorReal = _now();
  }

  set speed(double value) {
    _anchorSong = time;
    _anchorReal = _now();
    _speed = value.clamp(minSpeed, maxSpeed);
  }
}
