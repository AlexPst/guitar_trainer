import 'package:guitar_trainer/engine/note_event.dart';
import 'package:guitar_trainer/music/lesson.dart';
import 'package:guitar_trainer/music/pitch.dart';

/// 120 BPM (0.5 s per beat). Each entry: (beat, string, fret).
Lesson lessonOf(List<(double, int, int)> notes, {double bpm = 120}) => Lesson(
  id: 't',
  title: 'T',
  bpm: bpm,
  timeSignature: const TimeSignature(4, 4),
  notes: [
    for (final (b, s, f) in notes)
      TabNote(beat: b, string: s, fret: f, duration: 0.25),
  ],
);

/// A pluck as the audio layer reports it: attack first, pitch shortly after,
/// then the ringing note keeps reporting its pitch.
List<NoteEvent> pluck(
  double t,
  num midi, {
  double pitchDelay = 0.03,
  int ringFrames = 4,
}) {
  final f = midiToFrequency(midi);
  return [
    NoteEvent(t, null, onset: true),
    for (var i = 0; i <= ringFrames; i++)
      NoteEvent(t + pitchDelay + i * 0.046, f),
  ];
}

/// Pitch frames without an attack, e.g. a note still ringing.
List<NoteEvent> ring(double from, double to, num midi) => [
  for (var t = from; t < to; t += 0.046) NoteEvent(t, midiToFrequency(midi)),
];
