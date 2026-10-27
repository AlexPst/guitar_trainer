import 'pitch.dart';

class GuitarTuning {
  const GuitarTuning(this.openMidi);

  /// E4 B3 G3 D3 A2 E2.
  static const standard = GuitarTuning([64, 59, 55, 50, 45, 40]);

  /// MIDI numbers of open strings; index 0 is string 1 (the thinnest).
  final List<int> openMidi;

  int get stringCount => openMidi.length;

  /// Open-string MIDI for [string] numbered 1..[stringCount].
  int openMidiOf(int string) => openMidi[string - 1];

  /// The open string closest in pitch to [frequency], numbered 1..[stringCount].
  int nearestString(double frequency) {
    final midi = frequencyToMidi(frequency);
    var best = 1;
    for (var s = 2; s <= stringCount; s++) {
      if ((openMidiOf(s) - midi).abs() < (openMidiOf(best) - midi).abs()) {
        best = s;
      }
    }
    return best;
  }
}
