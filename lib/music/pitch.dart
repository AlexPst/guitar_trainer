import 'dart:math' as math;

const List<String> noteNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

double midiToFrequency(num midi) =>
    440 * math.pow(2, (midi - 69) / 12).toDouble();

/// Fractional MIDI number, e.g. 40.25 is E2 + 25 cents.
double frequencyToMidi(double frequency) =>
    69 + 12 * math.log(frequency / 440) / math.ln2;

/// Scientific pitch notation: 40 -> "E2", 61 -> "C#4".
String midiName(int midi) => '${noteNames[midi % 12]}${midi ~/ 12 - 1}';

/// The nearest equal-tempered note to a frequency and the deviation from it.
class NoteReading {
  const NoteReading({required this.midi, required this.cents});

  factory NoteReading.fromFrequency(double frequency) {
    final exact = frequencyToMidi(frequency);
    final midi = exact.round();
    return NoteReading(midi: midi, cents: (exact - midi) * 100);
  }

  final int midi;

  /// Deviation from [midi] in cents, in range [-50, 50].
  final double cents;

  String get name => midiName(midi);
}
