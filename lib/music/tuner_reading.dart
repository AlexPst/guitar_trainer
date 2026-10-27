import 'guitar_tuning.dart';
import 'pitch.dart';

/// What the tuner shows for one detected frequency.
class TunerReading {
  TunerReading(this.frequency, {GuitarTuning tuning = GuitarTuning.standard})
    : note = NoteReading.fromFrequency(frequency),
      string = tuning.nearestString(frequency),
      stringMidi = tuning.openMidiOf(tuning.nearestString(frequency));

  /// |cents| below this counts as in tune.
  static const inTuneCents = 5.0;

  final double frequency;
  final NoteReading note;

  /// Nearest open string, 1 (thinnest) .. 6.
  final int string;
  final int stringMidi;

  bool get inTune => note.cents.abs() < inTuneCents;
}
