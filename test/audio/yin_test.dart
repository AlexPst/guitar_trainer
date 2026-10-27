import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/audio/yin.dart';
import 'package:guitar_trainer/music/pitch.dart';

import 'signals.dart';

void main() {
  final yin = Yin(sampleRate: sampleRate);
  const n = 4096;

  // E2..E4 chromatically, plus detuned values between notes.
  final midis = [for (var m = 40; m <= 64; m++) m.toDouble(), 40.37, 52.81];

  for (final midi in midis) {
    final f = midiToFrequency(midi);
    test('sine ${f.toStringAsFixed(2)} Hz within 3 cents', () {
      final est = yin.detect(sine(f, n, phase: 0.3))!;
      expect(centsBetween(est.frequency, f).abs(), lessThan(3));
    });
    test('saw ${f.toStringAsFixed(2)} Hz within 3 cents', () {
      final est = yin.detect(saw(f, n))!;
      expect(centsBetween(est.frequency, f).abs(), lessThan(3));
    });
  }

  test('higher frets up to 1300 Hz', () {
    for (final f in [523.25, 880.0, 1318.5]) {
      final est = yin.detect(saw(f, n))!;
      expect(centsBetween(est.frequency, f).abs(), lessThan(3), reason: '$f');
    }
  });

  test('no pitch in silence or white noise', () {
    expect(yin.detect(sine(0, n, amp: 0)), isNull);
    expect(yin.detect(noise(n)), isNull);
  });

  test('confidence is high for clean tone', () {
    expect(yin.detect(sine(110, n))!.confidence, greaterThan(0.9));
  });

  test('window of 4096 is enough for the lowest frequency', () {
    expect(yin.minBufferSize, lessThanOrEqualTo(n));
  });
}
