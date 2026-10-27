import 'guitar_tuning.dart';
import 'pitch.dart';

class TabNote {
  const TabNote({
    required this.beat,
    required this.string,
    required this.fret,
    required this.duration,
  });

  /// Start position in beats from the beginning of the lesson.
  final double beat;

  /// 1 (thinnest, E4) .. 6 (thickest, E2).
  final int string;
  final int fret;

  /// Length in beats.
  final double duration;

  int midi([GuitarTuning tuning = GuitarTuning.standard]) =>
      tuning.openMidiOf(string) + fret;

  double frequency([GuitarTuning tuning = GuitarTuning.standard]) =>
      midiToFrequency(midi(tuning));
}

class TimeSignature {
  const TimeSignature(this.beatsPerBar, this.beatUnit);

  final int beatsPerBar;
  final int beatUnit;

  @override
  String toString() => '$beatsPerBar/$beatUnit';
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.bpm,
    required this.timeSignature,
    required this.notes,
    this.description,
  });

  final String id;
  final String title;
  final String? description;
  final double bpm;
  final TimeSignature timeSignature;

  /// Sorted by [TabNote.beat], no two notes on the same beat.
  final List<TabNote> notes;

  double get secondsPerBeat => 60 / bpm;

  /// Note start in seconds at 100% tempo.
  double noteTime(TabNote note) => note.beat * secondsPerBeat;

  double noteDuration(TabNote note) => note.duration * secondsPerBeat;

  /// Beat where the last note ends.
  double get lengthInBeats => notes.isEmpty
      ? 0
      : notes.map((n) => n.beat + n.duration).reduce((a, b) => a > b ? a : b);

  double get lengthInSeconds => lengthInBeats * secondsPerBeat;

  /// Bars needed to hold all notes, counting a partial last bar.
  int get barCount => (lengthInBeats / timeSignature.beatsPerBar).ceil();
}
