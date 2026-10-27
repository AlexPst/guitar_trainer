/// Something heard from the instrument, already mapped to song time.
class NoteEvent {
  const NoteEvent(this.time, this.frequency, {this.onset = false});

  /// Song time in seconds, before calibration offset is applied.
  final double time;

  /// Detected pitch; null when the attack is heard but pitch is not known yet.
  final double? frequency;

  /// True for a new attack (pluck). False for pitch updates of a ringing note.
  final bool onset;

  @override
  String toString() =>
      'NoteEvent(${time.toStringAsFixed(3)}, '
      '${frequency?.toStringAsFixed(1)}${onset ? ', onset' : ''})';
}
