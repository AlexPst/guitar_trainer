import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/audio/pitch_tracker.dart';

import 'signals.dart';

/// Feeds [signal] in mic-sized chunks and collects all readings.
List<double?> run(PitchTracker t, Float32List signal, {int chunk = 1024}) {
  final out = <double?>[];
  for (var i = 0; i < signal.length; i += chunk) {
    final end = (i + chunk).clamp(0, signal.length);
    out.addAll(t.add(Float32List.sublistView(signal, i, end)));
  }
  return out;
}

void main() {
  test('one reading per hop after the window fills', () {
    final t = PitchTracker(sampleRate: sampleRate);
    final readings = run(t, sine(110, 4096 + 2048 * 5));
    expect(readings, hasLength(5));
  });

  test('steady tone gives a stable frequency', () {
    final t = PitchTracker(sampleRate: sampleRate);
    final readings = run(t, saw(146.83, sampleRate)); // D3, 1 s
    expect(readings, isNotEmpty);
    for (final f in readings) {
      expect(centsBetween(f!, 146.83).abs(), lessThan(3));
    }
  });

  test('quiet signal is ignored', () {
    final t = PitchTracker(sampleRate: sampleRate);
    final readings = run(t, sine(110, sampleRate, amp: 0.0005));
    expect(readings.every((f) => f == null), isTrue);
  });

  test('holds value through a short gap, drops after longer silence', () {
    final t = PitchTracker(sampleRate: sampleRate);
    run(t, saw(110, sampleRate ~/ 2));
    // Each hop of silence is one silent frame once the window is flushed.
    final gap = run(t, Float32List(4096 + 2048 * 4));
    expect(gap.first, isNotNull); // window still partly has the tone
    expect(gap.last, isNull);
  });

  test('median rejects a single outlier frame', () {
    final t = PitchTracker(sampleRate: sampleRate, windowSize: 4096);
    run(t, saw(196, sampleRate ~/ 2));
    // A short burst of a different note affects at most a couple of frames.
    final burst = run(t, saw(392, 2048));
    final after = run(t, saw(196, 2048 * 2));
    expect(centsBetween(burst.last!, 196).abs(), lessThan(3));
    expect(centsBetween(after.last!, 196).abs(), lessThan(3));
  });
}
