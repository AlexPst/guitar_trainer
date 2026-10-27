import 'dart:typed_data';

import 'level_meter.dart';

/// Detects attacks (plucks) by a sudden rise of short-term energy.
///
/// Works on blocks of [hopSize] samples. An onset is reported when a block is
/// louder than [minLevelDbfs] and at least [riseDb] above the quietest of the
/// previous [lookback] blocks, and [refractory] seconds have passed since the
/// last onset. A re-pluck of the same string mutes and re-excites it, which
/// gives such a jump, so repeated equal notes are detected separately.
class OnsetDetector {
  OnsetDetector({
    required this.sampleRate,
    this.hopSize = 256,
    this.riseDb = 5,
    this.minLevelDbfs = -50,
    this.lookback = 3,
    this.refractory = 0.08,
  }) : _block = Float32List(hopSize),
       _history = List.filled(lookback, minDbfs);

  final int sampleRate;
  final int hopSize;
  final double riseDb;
  final double minLevelDbfs;
  final int lookback;
  final double refractory;

  final Float32List _block;
  final List<double> _history;
  int _filled = 0;
  int _historyPos = 0;
  int _samples = 0;
  double _lastOnset = double.negativeInfinity;

  /// Feeds samples; returns onset times in seconds since the first sample.
  List<double> add(Float32List chunk) {
    final out = <double>[];
    for (var i = 0; i < chunk.length; i++) {
      _block[_filled++] = chunk[i];
      _samples++;
      if (_filled == hopSize) {
        _filled = 0;
        final t = (_samples - hopSize) / sampleRate;
        if (_analyse(t)) out.add(t);
      }
    }
    return out;
  }

  void reset() {
    _filled = 0;
    _samples = 0;
    _historyPos = 0;
    _history.fillRange(0, lookback, minDbfs);
    _lastOnset = double.negativeInfinity;
  }

  bool _analyse(double t) {
    final level = rmsToDbfs(rms(_block));
    var floor = _history[0];
    for (final h in _history) {
      if (h < floor) floor = h;
    }
    _history[_historyPos] = level;
    _historyPos = (_historyPos + 1) % lookback;

    if (level < minLevelDbfs || level - floor < riseDb) return false;
    if (t - _lastOnset < refractory) return false;
    _lastOnset = t;
    return true;
  }
}
