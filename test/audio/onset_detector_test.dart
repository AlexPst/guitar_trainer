import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/audio/onset_detector.dart';

import 'signals.dart';

/// Plucked string model: harmonic tone with exponential decay, restarted at
/// each time in [plucks]. Before a re-pluck the pick touches the string and
/// damps it for [muteMs], as on a real guitar.
Float32List plucked(
  double freq,
  List<double> plucks,
  double length, {
  double amp = 0.6,
  double decay = 0.4,
  double muteMs = 8,
}) {
  final mute = (muteMs / 1000 * sampleRate).round();
  final n = (length * sampleRate).round();
  final out = Float32List(n);
  for (var p = 0; p < plucks.length; p++) {
    final start = (plucks[p] * sampleRate).round();
    final end = p + 1 < plucks.length
        ? (plucks[p + 1] * sampleRate).round()
        : n;
    for (var i = start; i < end && i < n; i++) {
      final t = (i - start) / sampleRate;
      final toNext = end - i;
      final damp = p + 1 < plucks.length && toNext < mute ? toNext / mute : 1;
      final env = amp * math.exp(-t / decay) * damp;
      out[i] =
          env *
          (math.sin(2 * math.pi * freq * t) +
              0.5 * math.sin(4 * math.pi * freq * t)) /
          1.5;
    }
  }
  return out;
}

List<double> detect(Float32List signal, {int chunk = 1024}) {
  final d = OnsetDetector(sampleRate: sampleRate);
  final out = <double>[];
  for (var i = 0; i < signal.length; i += chunk) {
    final end = math.min(i + chunk, signal.length);
    out.addAll(d.add(Float32List.sublistView(signal, i, end)));
  }
  return out;
}

void main() {
  test('single pluck after silence', () {
    final onsets = detect(plucked(110, [0.3], 1.5));
    expect(onsets, hasLength(1));
    expect(onsets.single, closeTo(0.3, 0.025));
  });

  test('repeated plucks of the same note are separate onsets', () {
    final times = [0.2, 0.7, 1.2, 1.7];
    final onsets = detect(plucked(110, times, 2.5));
    expect(onsets, hasLength(times.length));
    for (var i = 0; i < times.length; i++) {
      expect(onsets[i], closeTo(times[i], 0.025));
    }
  });

  test('fast repeats 150 ms apart', () {
    final times = [for (var i = 0; i < 6; i++) 0.1 + i * 0.15];
    final onsets = detect(plucked(196, times, 1.5, decay: 0.3));
    expect(onsets, hasLength(times.length));
  });

  test('steady tone gives one onset', () {
    final tone = Float32List(
      sampleRate * 2,
    )..setRange(sampleRate ~/ 2, sampleRate * 2, saw(147, sampleRate * 3 ~/ 2));
    expect(detect(tone), hasLength(1));
  });

  test('tremolo of ±1.5 dB on a steady tone is not an attack', () {
    final n = sampleRate * 3;
    final tone = Float32List(n);
    for (var i = sampleRate ~/ 2; i < n; i++) {
      final t = i / sampleRate;
      final db = 1.5 * math.sin(2 * math.pi * 5 * t);
      tone[i] = 0.4 * math.pow(10, db / 20) * math.sin(2 * math.pi * 220 * t);
    }
    expect(detect(tone), hasLength(1)); // only the start
  });

  test('silence and quiet noise give none', () {
    expect(detect(Float32List(sampleRate)), isEmpty);
    expect(detect(noise(sampleRate, amp: 0.001)), isEmpty);
  });

  test('time is counted across chunk sizes', () {
    final signal = plucked(110, [0.5], 1);
    expect(detect(signal, chunk: 300).single, detect(signal).single);
  });
}
