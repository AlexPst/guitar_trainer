import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/data/lesson_repository.dart';
import 'package:guitar_trainer/engine/lesson_result.dart';
import 'package:guitar_trainer/engine/note_result.dart';
import 'package:guitar_trainer/game/lesson_game.dart';
import 'package:guitar_trainer/music/lesson.dart';
import 'package:guitar_trainer/ui/result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/fake_time.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(
    LessonResult r, {
    bool best = false,
    List<LessonEntry>? lessons,
  }) => ProviderScope(
    overrides: [
      lessonsProvider.overrideWith((ref) async => lessons ?? const []),
    ],
    child: MaterialApp(
      home: ResultScreen(
        result: r,
        isNewBest: best,
        mode: r.scored ? LessonMode.tempo : LessonMode.wait,
        speed: 1,
      ),
    ),
  );

  LessonResult result(List<Judgement> js, {bool scored = true}) => LessonResult(
    lesson: testLesson(beats: js.length),
    results: [
      for (var i = 0; i < js.length; i++)
        NoteResult(i, js[i], timingError: js[i] == Judgement.late ? 0.09 : 0),
    ],
    scored: scored,
    maxCombo: 2,
  );

  testWidgets('shows accuracy, stars, record and mistakes', (tester) async {
    final r = result([
      Judgement.hit,
      Judgement.hit,
      Judgement.late,
      Judgement.hit,
      Judgement.miss,
    ]);
    await tester.pumpWidget(host(r, best: true));
    await tester.pumpAndSettle();
    expect(find.text('74%'), findsOneWidget); // (300 + 70) / 500
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(1));
    expect(find.text('Новый рекорд!'), findsOneWidget);
    expect(find.text('Разбор ошибок'), findsOneWidget);
    expect(find.textContaining('поздно, +90 мс'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('не сыграна'), 200);
    expect(find.textContaining('не сыграна'), findsOneWidget);
    expect(find.textContaining('такт 1, доля 3'), findsOneWidget);
  });

  testWidgets('wait mode: no stars, explains', (tester) async {
    await tester.pumpWidget(host(result([Judgement.hit], scored: false)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.textContaining('Все 1 нот'), findsOneWidget);
    expect(find.text('Разбор ошибок'), findsNothing);
  });

  testWidgets('next lesson button only when it is unlocked', (tester) async {
    final first = testLesson(beats: 3);
    const second = Lesson(
      id: 'second',
      title: 'Второй',
      bpm: 60,
      timeSignature: TimeSignature(4, 4),
      notes: [TabNote(beat: 0, string: 1, fret: 0, duration: 1)],
    );
    final lessons = [
      LessonEntry.ok('a', first),
      const LessonEntry.ok('b', second),
    ];

    await tester.pumpWidget(
      host(result(List.filled(3, Judgement.miss)), lessons: lessons),
    );
    await tester.pumpAndSettle();
    expect(find.text('Следующий урок'), findsNothing);

    SharedPreferences.setMockInitialValues({
      'progress.t': '{"bestAccuracy":1.0,"bestScore":300,"stars":3}',
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      host(result(List.filled(3, Judgement.hit)), lessons: lessons),
    );
    await tester.pumpAndSettle();
    expect(find.text('Следующий урок'), findsOneWidget);
  });

  test('note position text', () {
    final l = Lesson(
      id: 'x',
      title: 'x',
      bpm: 60,
      timeSignature: const TimeSignature(4, 4),
      notes: const [
        TabNote(beat: 0, string: 1, fret: 0, duration: 1),
        TabNote(beat: 5.5, string: 1, fret: 0, duration: 1),
      ],
    );
    expect(notePosition(l, l.notes[0]), 'такт 1, доля 1');
    expect(notePosition(l, l.notes[1]), 'такт 2, доля 2½');
  });
}
