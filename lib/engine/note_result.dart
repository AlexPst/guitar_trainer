enum Judgement {
  /// Right pitch, within the tight window.
  hit,

  /// Right pitch, before the tight window but inside the hit window.
  early,

  /// Right pitch, after the tight window but inside the hit window.
  late,

  /// Right note an octave off. Counted as "almost".
  octave,

  /// Attack in the window with a different pitch.
  wrongPitch,

  /// Nothing usable in the window.
  miss;

  /// Right pitch at roughly the right time.
  bool get isPlayed => this == hit || this == early || this == late;
}

class NoteResult {
  const NoteResult(
    this.noteIndex,
    this.judgement, {
    this.timingError,
    this.cents,
  });

  final int noteIndex;
  final Judgement judgement;

  /// Seconds of song time, negative when early. Null for misses.
  final double? timingError;

  /// Deviation from the target (or its octave) in cents, when pitched.
  final double? cents;

  @override
  String toString() {
    final dt = timingError == null
        ? ''
        : ' ${(timingError! * 1000).toStringAsFixed(0)}ms';
    return 'NoteResult(#$noteIndex ${judgement.name}$dt)';
  }
}
