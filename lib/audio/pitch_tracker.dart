import 'dart:typed_data';

import 'level_meter.dart';
import 'yin.dart';

/// Turns a stream of sample chunks into smoothed pitch readings.
///
/// Every [hopSize] samples it analyses the last [windowSize] samples and
/// reports a frequency, or null when the signal is too quiet or unpitched.
class PitchTracker {
  PitchTracker({
    required int sampleRate,
    this.windowSize = 4096,
    this.hopSize = 2048,
    this.minLevelDbfs = -55,
    this.smoothing = 5,
    this.dropAfterSilentFrames = 3,
  }) : _yin = Yin(sampleRate: sampleRate),
       _window = Float32List(windowSize) {
    assert(windowSize >= _yin.minBufferSize);
  }

  final int windowSize;
  final int hopSize;
  final double minLevelDbfs;

  /// Median filter length over recent valid estimates.
  final int smoothing;

  /// Consecutive empty frames after which the history is cleared.
  final int dropAfterSilentFrames;

  final Yin _yin;

  /// Contiguous copy of the ring, oldest sample first; passed to YIN.
  final Float32List _window;
  late final Float32List _ring = Float32List(windowSize);
  int _ringPos = 0;
  int _filled = 0;
  int _sinceLastFrame = 0;
  final List<double> _recent = [];
  int _silentFrames = 0;
  int _samples = 0;

  /// Feeds samples; returns one reading per analysed frame (possibly none).
  List<double?> add(Float32List chunk) => [
    for (final (_, f) in addTimed(chunk)) f,
  ];

  /// Like [add], with the number of samples consumed so far at each frame,
  /// i.e. the position just after the window's last sample.
  List<(int, double?)> addTimed(Float32List chunk) {
    final out = <(int, double?)>[];
    for (var i = 0; i < chunk.length; i++) {
      _samples++;
      _ring[_ringPos] = chunk[i];
      _ringPos = (_ringPos + 1) % windowSize;
      if (_filled < windowSize) _filled++;
      if (_filled == windowSize && ++_sinceLastFrame >= hopSize) {
        _sinceLastFrame = 0;
        _window
          ..setRange(0, windowSize - _ringPos, _ring, _ringPos)
          ..setRange(windowSize - _ringPos, windowSize, _ring);
        out.add((_samples, _analyse()));
      }
    }
    return out;
  }

  void reset() {
    _samples = 0;
    _ringPos = 0;
    _filled = 0;
    _sinceLastFrame = 0;
    _recent.clear();
    _silentFrames = 0;
  }

  double? _analyse() {
    double? frequency;
    if (rmsToDbfs(rms(_window)) >= minLevelDbfs) {
      frequency = _yin.detect(_window)?.frequency;
    }
    if (frequency == null) {
      // Hold the last value through short gaps so the display doesn't blink.
      if (++_silentFrames >= dropAfterSilentFrames) _recent.clear();
      return _recent.isEmpty ? null : _median(_recent);
    }
    _silentFrames = 0;
    _recent.add(frequency);
    if (_recent.length > smoothing) _recent.removeAt(0);
    return _median(_recent);
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
