import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/engine/pitch_match.dart';
import 'package:guitar_trainer/music/pitch.dart';

void main() {
  PitchMatchKind kind(num midi, int target) =>
      matchPitch(midiToFrequency(midi), target).kind;

  test('within ±50 cents is a match', () {
    expect(kind(45, 45), PitchMatchKind.match);
    expect(kind(45.49, 45), PitchMatchKind.match);
    expect(kind(44.51, 45), PitchMatchKind.match);
    expect(matchPitch(midiToFrequency(45.2), 45).cents, closeTo(20, 1e-6));
  });

  test('neighbour semitone is wrong', () {
    expect(kind(46, 45), PitchMatchKind.wrong);
    expect(kind(44.4, 45), PitchMatchKind.wrong);
  });

  test('octave up and down', () {
    expect(kind(57, 45), PitchMatchKind.octave);
    expect(kind(33, 45), PitchMatchKind.octave);
    final m = matchPitch(midiToFrequency(57.3), 45);
    expect(m.kind, PitchMatchKind.octave);
    expect(m.cents, closeTo(30, 1e-6));
  });

  test('two octaves or a fifth are wrong', () {
    expect(kind(69, 45), PitchMatchKind.wrong);
    expect(kind(52, 45), PitchMatchKind.wrong);
  });
}
