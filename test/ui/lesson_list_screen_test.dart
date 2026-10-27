import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/data/lesson_repository.dart';
import 'package:guitar_trainer/music/lesson.dart';
import 'package:guitar_trainer/music/lesson_parser.dart';
import 'package:guitar_trainer/ui/lesson_list_screen.dart';

const _lesson = Lesson(
  id: 'a',
  title: 'Открытые струны',
  description: 'Сверху вниз',
  bpm: 60,
  timeSignature: TimeSignature(4, 4),
  notes: [
    TabNote(beat: 0, string: 6, fret: 0, duration: 1),
    TabNote(beat: 1, string: 5, fret: 0, duration: 69),
  ],
);

Widget app(List<LessonEntry> entries) => ProviderScope(
  overrides: [lessonsProvider.overrideWith((ref) async => entries)],
  child: const MaterialApp(home: LessonListScreen()),
);

void main() {
  testWidgets('shows lessons with stats', (tester) async {
    await tester.pumpWidget(app([const LessonEntry.ok('a.json', _lesson)]));
    await tester.pump();
    expect(find.text('Открытые струны'), findsOneWidget);
    expect(find.textContaining('Сверху вниз'), findsOneWidget);
    expect(find.textContaining('60 BPM · 2 ноты · 1:10'), findsOneWidget);
  });

  testWidgets('broken lesson shows its error', (tester) async {
    await tester.pumpWidget(
      app([
        const LessonEntry.broken(
          'b.json',
          LessonFormatException(
            'bpm',
            'должен быть от 20 до 300',
            source: 'b.json',
          ),
        ),
      ]),
    );
    await tester.pump();
    expect(find.text('Ошибка в уроке'), findsOneWidget);
    expect(find.textContaining('b.json: bpm'), findsOneWidget);
  });

  testWidgets('debug menu opens Flame screen', (tester) async {
    await tester.pumpWidget(app(const []));
    await tester.pump();
    expect(find.text('Уроков нет'), findsOneWidget);
    await tester.tap(find.byTooltip('Отладка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flame'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.widgetWithText(AppBar, 'Flame'), findsOneWidget);
  });

  test('ruPlural', () {
    String f(int n) => '$n ${ruPlural(n, 'нота', 'ноты', 'нот')}';
    expect([1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 101, 111].map(f).toList(), [
      '1 нота',
      '2 ноты',
      '4 ноты',
      '5 нот',
      '11 нот',
      '12 нот',
      '14 нот',
      '21 нота',
      '22 ноты',
      '25 нот',
      '101 нота',
      '111 нот',
    ]);
  });
}
