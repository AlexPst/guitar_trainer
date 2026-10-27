import 'dart:typed_data';

class PitchEstimate {
  const PitchEstimate(this.frequency, this.confidence);

  final double frequency;

  /// 1 - CMND value at the chosen lag; close to 1 for clean periodic signals.
  final double confidence;
}

/// YIN pitch detector (de Cheveigné & Kawahara, 2002).
///
/// Buffers passed to [detect] must have at least [minBufferSize] samples.
class Yin {
  Yin({
    required this.sampleRate,
    this.minFrequency = 60,
    this.maxFrequency = 1400,
    this.threshold = 0.12,
  }) : _tauMin = (sampleRate / maxFrequency).floor(),
       _tauMax = (sampleRate / minFrequency).ceil() {
    _cmnd = Float64List(_tauMax + 2);
  }

  final int sampleRate;
  final double minFrequency;
  final double maxFrequency;
  final double threshold;

  final int _tauMin;
  final int _tauMax;
  late final Float64List _cmnd;

  /// Lowest frequency needs two periods plus margin for interpolation.
  int get minBufferSize => _tauMax * 2 + 2;

  PitchEstimate? detect(Float32List x) {
    assert(x.length >= minBufferSize);
    final tauMax = _tauMax + 1;
    final window = x.length - tauMax;

    // Difference function + cumulative mean normalization in one pass.
    _cmnd[0] = 1;
    var runningSum = 0.0;
    for (var tau = 1; tau <= tauMax; tau++) {
      var d = 0.0;
      for (var j = 0; j < window; j++) {
        final delta = x[j] - x[j + tau];
        d += delta * delta;
      }
      runningSum += d;
      _cmnd[tau] = runningSum == 0 ? 1 : d * tau / runningSum;
    }

    // First dip below threshold, then walk down to its local minimum.
    var tau = _tauMin;
    while (tau < _tauMax && _cmnd[tau] >= threshold) {
      tau++;
    }
    if (tau >= _tauMax) return null;
    while (tau + 1 < _tauMax && _cmnd[tau + 1] < _cmnd[tau]) {
      tau++;
    }

    final refined = _parabolicPeak(tau);
    return PitchEstimate(sampleRate / refined, 1 - _cmnd[tau]);
  }

  double _parabolicPeak(int tau) {
    final a = _cmnd[tau - 1];
    final b = _cmnd[tau];
    final c = _cmnd[tau + 1];
    final denom = a - 2 * b + c;
    if (denom == 0) return tau.toDouble();
    return tau + 0.5 * (a - c) / denom;
  }
}
