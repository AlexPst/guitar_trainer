import 'dart:math' as math;
import 'dart:typed_data';

import 'level_meter.dart';

/// Detects attacks (plucks) by a sudden rise of short-term energy.
///
/// Every [hopSize] samples it measures the level of the last
/// [hopSize] × [windowBlocks] samples. The window spans about two periods of
/// the lowest guitar note, so the level does not ripple with the waveform
/// phase of low notes. An onset is reported when the level is above
/// [minLevelDbfs] and at least [riseDb] above the quietest of the previous
/// [lookback] measurements, and [refractory] seconds have passed since the
/// last onset. A re-pluck of the same string mutes and re-excites it, which
/// gives such a jump, so repeated equal notes are detected separately.
///
/// With [confirmAfter] > 0 a candidate is reported only if, that many seconds
/// later, the level is still [sustainDb] above the level before it. A plucked
/// string keeps ringing; a short click (e.g. our own metronome heard through
/// the mic) has died out by then and is dropped. Reported times are still the
/// attack times, so results arrive [confirmAfter] late.
class OnsetDetector {
  OnsetDetector({
    required this.sampleRate,
    this.hopSize = 256,
    this.windowBlocks = 4,
    this.riseDb = 3,
    this.minLevelDbfs = -50,
    this.lookback = 4,
    this.refractory = 0.08,
    this.confirmAfter = 0,
    this.sustainDb = 2,
  }) : _block = Float32List(hopSize),
       _blockEnergy = Float64List(windowBlocks),
       _history = List.filled(lookback, minDbfs);

  final int sampleRate;
  final int hopSize;
  final int windowBlocks;
  final double riseDb;
  final double minLevelDbfs;
  final int lookback;
  final double refractory;
  final double confirmAfter;
  final double sustainDb;

  /// Candidates waiting for confirmation: (time, level before the attack).
  final List<(double, double)> _pending = [];

  final Float32List _block;

  /// Sum of squares of the last [windowBlocks] blocks (ring).
  final Float64List _blockEnergy;
  int _blockPos = 0;
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
        _analyse((_samples - hopSize) / sampleRate, out);
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
    _pending.clear();
    _blockEnergy.fillRange(0, windowBlocks, 0);
    _blockPos = 0;
  }

  void _analyse(double t, List<double> out) {
    var sum = 0.0;
    for (final s in _block) {
      sum += s * s;
    }
    _blockEnergy[_blockPos] = sum;
    _blockPos = (_blockPos + 1) % windowBlocks;
    var total = 0.0;
    for (final e in _blockEnergy) {
      total += e;
    }
    final level = rmsToDbfs(math.sqrt(total / (hopSize * windowBlocks)));
    var floor = _history[0];
    for (final h in _history) {
      if (h < floor) floor = h;
    }
    _history[_historyPos] = level;
    _historyPos = (_historyPos + 1) % lookback;

    while (_pending.isNotEmpty && t - _pending.first.$1 >= confirmAfter) {
      final (time, before) = _pending.removeAt(0);
      if (level - before >= sustainDb) out.add(time);
    }

    if (level < minLevelDbfs || level - floor < riseDb) return;
    if (t - _lastOnset < refractory) return;
    _lastOnset = t;
    if (confirmAfter <= 0) {
      out.add(t);
    } else {
      _pending.add((t, floor));
    }
  }
}
