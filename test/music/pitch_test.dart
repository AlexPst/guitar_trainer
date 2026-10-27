import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/music/guitar_tuning.dart';
import 'package:guitar_trainer/music/pitch.dart';
import 'package:guitar_trainer/music/tuner_reading.dart';

void main() {
  test('midi <-> frequency', () {
    expect(midiToFrequency(69), 440);
    expect(midiToFrequency(40), closeTo(82.4069, 1e-3)); // E2
    expect(midiToFrequency(64), closeTo(329.6276, 1e-3)); // E4
    expect(frequencyToMidi(440), closeTo(69, 1e-9));
    expect(frequencyToMidi(midiToFrequency(52.3)), closeTo(52.3, 1e-9));
  });

  test('note names', () {
    expect(midiName(40), 'E2');
    expect(midiName(45), 'A2');
    expect(midiName(60), 'C4');
    expect(midiName(61), 'C#4');
    expect(midiName(59), 'B3');
  });

  test('NoteReading rounds to nearest note and keeps cents', () {
    final sharp = NoteReading.fromFrequency(midiToFrequency(45.2));
    expect(sharp.name, 'A2');
    expect(sharp.cents, closeTo(20, 1e-6));

    final flat = NoteReading.fromFrequency(midiToFrequency(49.7));
    expect(flat.name, 'D3');
    expect(flat.cents, closeTo(-30, 1e-6));
  });

  test('standard tuning open strings', () {
    const t = GuitarTuning.standard;
    expect(
      [for (var s = 1; s <= 6; s++) midiName(t.openMidiOf(s))],
      ['E4', 'B3', 'G3', 'D3', 'A2', 'E2'],
    );
  });

  test('nearest string', () {
    const t = GuitarTuning.standard;
    expect(t.nearestString(82.4), 6);
    expect(t.nearestString(85), 6); // slightly sharp E2
    expect(t.nearestString(108), 5); // flat A2
    expect(t.nearestString(147), 4);
    expect(t.nearestString(196), 3);
    expect(t.nearestString(250), 2);
    expect(t.nearestString(330), 1);
    expect(t.nearestString(1000), 1);
  });

  test('TunerReading in tune threshold', () {
    expect(TunerReading(midiToFrequency(40.04)).inTune, isTrue);
    expect(TunerReading(midiToFrequency(40.06)).inTune, isFalse);
    expect(TunerReading(midiToFrequency(50)).string, 4);
  });
}
