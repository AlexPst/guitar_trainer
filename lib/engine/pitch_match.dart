import '../music/pitch.dart';

enum PitchMatchKind { match, octave, wrong }

class PitchMatch {
  const PitchMatch(this.kind, this.cents);

  final PitchMatchKind kind;

  /// Deviation from the target (for [PitchMatchKind.octave], from the target
  /// shifted by an octave), in cents.
  final double cents;
}

/// Same note: within [tolerance] cents. Octave error: ×2 or ×0.5 within the
/// same tolerance. String and fret are not checked, only pitch.
PitchMatch matchPitch(
  double frequency,
  int targetMidi, {
  double tolerance = 50,
}) {
  final diff = (frequencyToMidi(frequency) - targetMidi) * 100;
  if (diff.abs() <= tolerance) return PitchMatch(PitchMatchKind.match, diff);
  for (final octave in const [1200.0, -1200.0]) {
    final d = diff - octave;
    if (d.abs() <= tolerance) return PitchMatch(PitchMatchKind.octave, d);
  }
  return PitchMatch(PitchMatchKind.wrong, diff);
}
