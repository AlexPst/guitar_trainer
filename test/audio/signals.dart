import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 44100;

Float32List sine(double freq, int n, {double amp = 0.5, double phase = 0}) =>
    Float32List.fromList([
      for (var i = 0; i < n; i++)
        amp * math.sin(2 * math.pi * freq * i / sampleRate + phase),
    ]);

/// Band-limited sawtooth (additive), rich in harmonics like a plucked string.
Float32List saw(double freq, int n, {double amp = 0.5}) {
  final out = Float32List(n);
  final harmonics = (sampleRate / 2 / freq).floor().clamp(1, 40);
  for (var k = 1; k <= harmonics; k++) {
    final a = amp * 2 / math.pi / k * (k.isOdd ? 1 : -1);
    for (var i = 0; i < n; i++) {
      out[i] += a * math.sin(2 * math.pi * freq * k * i / sampleRate);
    }
  }
  return out;
}

/// Deterministic white noise in [-amp, amp].
Float32List noise(int n, {double amp = 0.5, int seed = 1}) {
  final rnd = math.Random(seed);
  return Float32List.fromList([
    for (var i = 0; i < n; i++) amp * (rnd.nextDouble() * 2 - 1),
  ]);
}

double centsBetween(double f, double ref) =>
    1200 * math.log(f / ref) / math.ln2;
