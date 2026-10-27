import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/engine/lesson_result.dart';
import 'package:guitar_trainer/engine/note_result.dart';
import 'package:guitar_trainer/engine/practice.dart';
import 'package:guitar_trainer/music/lesson.dart';

/// 4/4, one note per beat for [bars] bars.
Lesson bars(int bars) => Lesson(
  id: 'l',
  title: 'Урок',
  bpm: 120,
  timeSignature: const TimeSignature(4, 4),
  notes: [
    for (var b = 0; b < bars * 4; b++)
      TabNote(beat: b.toDouble(), string: 1, fret: b % 5, duration: 1),
  ],
);

LessonResult resultWith(Lesson l, Map<int, Judgement> bad) => LessonResult(
  lesson: l,
  results: [
    for (var i = 0; i < l.notes.length; i++)
      NoteResult(i, bad[i] ?? Judgement.hit),
  ],
  scored: true,
  maxCombo: 0,
);

void main() {
  group('excerpt', () {
    test('cuts bars and shifts to beat 0', () {
      final l = bars(4);
      final e = l.excerpt(2, 3)!;
      expect(e.notes, hasLength(8));
      expect(e.notes.first.beat, 0);
      expect(e.notes.first.fret, l.notes[4].fret);
      expect(e.barCount, 2);
      expect(e.title, 'Урок (такты 2–3)');
      expect(e.id, 'l#2-3');
    });

    test('long note is cut at the end of the excerpt', () {
      const l = Lesson(
        id: 'x',
        title: 'X',
        bpm: 60,
        timeSignature: TimeSignature(4, 4),
        notes: [TabNote(beat: 2, string: 1, fret: 0, duration: 6)],
      );
      final e = l.excerpt(1, 1)!;
      expect(e.notes.single.duration, 2);
      expect(e.lengthInBeats, 4);
      expect(e.title, 'X (такт 1)');
    });

    test('empty bars give null', () {
      expect(bars(2).excerpt(5, 6), isNull);
    });
  });

  group('hardestBars', () {
    test('finds the two bars with most mistakes', () {
      final l = bars(6);
      final r = resultWith(l, {
        1: Judgement.late, // bar 1, light
        13: Judgement.miss, // bar 4
        15: Judgement.wrongPitch, // bar 4
        17: Judgement.miss, // bar 5
      });
      expect(hardestBars(r), (4, 5));
      expect(hardestBars(r, span: 1), (4, 4));
    });

    test('clean run: nothing to practise', () {
      expect(hardestBars(resultWith(bars(3), {})), isNull);
    });

    test('short lesson: span shrinks to its length', () {
      expect(hardestBars(resultWith(bars(1), {0: Judgement.miss})), (1, 1));
    });
  });

  test('nextSpeed adapts in 10% steps within 50..100%', () {
    expect(nextSpeed(0.7, 0.95), 0.8);
    expect(nextSpeed(0.7, 0.75), 0.7);
    expect(nextSpeed(0.7, 0.4), 0.6);
    expect(nextSpeed(1.0, 1.0), 1.0);
    expect(nextSpeed(0.5, 0.0), 0.5);
    // No float drift over many steps.
    var s = 0.5;
    for (var i = 0; i < 5; i++) {
      s = nextSpeed(s, 1);
    }
    expect(s, 1.0);
  });
}
