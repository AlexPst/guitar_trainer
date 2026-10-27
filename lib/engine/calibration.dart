/// Measured latency between metronome clicks and the player's attacks.
class CalibrationResult {
  const CalibrationResult(this.offset, this.spread, this.matched);

  /// Median of (attack − click), seconds. Positive: heard later than clicked.
  final double offset;

  /// Robust spread (1.4826 × MAD) of the kept offsets, seconds.
  final double spread;

  /// Clicks that got an attack and were kept after dropping outliers.
  final int matched;
}

double _median(List<double> xs) {
  final s = [...xs]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

/// Estimates input + output latency from [clicks] and [onsets] (same clock).
///
/// Each click takes the closest unused attack within [before]..[after] of it.
/// Offsets far from the median (missed beats, double plucks) are dropped.
/// Returns null with fewer than [minMatches] usable clicks.
CalibrationResult? estimateLatency(
  List<double> clicks,
  List<double> onsets, {
  double before = 0.15,
  double after = 0.4,
  int minMatches = 6,
}) {
  final used = <int>{};
  final offsets = <double>[];
  for (final c in clicks) {
    int? best;
    for (var i = 0; i < onsets.length; i++) {
      final d = onsets[i] - c;
      if (used.contains(i) || d < -before || d > after) continue;
      if (best == null || d.abs() < (onsets[best] - c).abs()) best = i;
    }
    if (best != null) {
      used.add(best);
      offsets.add(onsets[best] - c);
    }
  }
  if (offsets.length < minMatches) return null;

  final m = _median(offsets);
  final mad = 1.4826 * _median([for (final o in offsets) (o - m).abs()]);
  // At least 30 ms of tolerance so a very steady player isn't over-trimmed.
  final limit = mad * 3 < 0.03 ? 0.03 : mad * 3;
  final kept = [
    for (final o in offsets)
      if ((o - m).abs() <= limit) o,
  ];
  if (kept.length < minMatches) return null;
  final km = _median(kept);
  final spread = 1.4826 * _median([for (final o in kept) (o - km).abs()]);
  return CalibrationResult(km, spread, kept.length);
}
