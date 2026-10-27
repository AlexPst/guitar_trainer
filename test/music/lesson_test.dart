import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/music/lesson.dart';

Lesson lesson({double bpm = 120, List<TabNote>? notes}) => Lesson(
  id: 't',
  title: 'T',
  bpm: bpm,
  timeSignature: const TimeSignature(4, 4),
  notes:
      notes ??
      const [
        TabNote(beat: 0, string: 6, fret: 0, duration: 1),
        TabNote(beat: 2, string: 1, fret: 5, duration: 0.5),
        TabNote(beat: 4.5, string: 3, fret: 2, duration: 2),
      ],
);

void main() {
  test('note times from beat and bpm', () {
    final l = lesson();
    expect(l.secondsPerBeat, 0.5);
    expect(l.noteTime(l.notes[0]), 0);
    expect(l.noteTime(l.notes[1]), 1.0);
    expect(l.noteTime(l.notes[2]), 2.25);
    expect(l.noteDuration(l.notes[2]), 1.0);
  });

  test('times scale with tempo', () {
    final l = lesson(bpm: 60);
    expect(l.noteTime(l.notes[2]), 4.5);
  });

  test('lesson length ends with the last note', () {
    final l = lesson();
    expect(l.lengthInBeats, 6.5);
    expect(l.lengthInSeconds, 3.25);
    expect(l.barCount, 2);
  });

  test('lengthInBeats uses the note that ends last, not starts last', () {
    final l = lesson(
      notes: const [
        TabNote(beat: 0, string: 6, fret: 0, duration: 8),
        TabNote(beat: 1, string: 5, fret: 0, duration: 1),
      ],
    );
    expect(l.lengthInBeats, 8);
  });

  test('target pitch from standard tuning', () {
    const e2 = TabNote(beat: 0, string: 6, fret: 0, duration: 1);
    const a4 = TabNote(beat: 0, string: 1, fret: 5, duration: 1);
    const b3 = TabNote(beat: 0, string: 3, fret: 4, duration: 1);
    expect(e2.midi(), 40);
    expect(e2.frequency(), closeTo(82.41, 0.01));
    expect(a4.frequency(), closeTo(440, 1e-9));
    expect(b3.midi(), 59); // same pitch as open string 2
  });
}
