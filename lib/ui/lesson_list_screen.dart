import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lesson_repository.dart';
import '../music/lesson.dart';
import 'flame_sandbox_screen.dart';
import 'lesson_screen.dart';
import 'mic_test_screen.dart';
import 'tuner_screen.dart';

/// Main menu: list of lessons plus entry points to the tuner and debug screens.
class LessonListScreen extends ConsumerWidget {
  const LessonListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));

    final lessons = ref.watch(lessonsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уроки'),
        actions: [
          IconButton(
            tooltip: 'Тюнер',
            icon: const Icon(Icons.tune),
            onPressed: () => open(const TunerScreen()),
          ),
          PopupMenuButton<Widget>(
            tooltip: 'Отладка',
            onSelected: open,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: MicTestScreen(),
                child: Text('Проверка микрофона'),
              ),
              PopupMenuItem(value: FlameSandboxScreen(), child: Text('Flame')),
            ],
          ),
        ],
      ),
      body: switch (lessons) {
        AsyncData(:final value) when value.isEmpty => const Center(
          child: Text('Уроков нет'),
        ),
        AsyncData(:final value) => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: value.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => _LessonTile(entry: value[i], index: i),
        ),
        AsyncError(:final error) => Center(
          child: Text('Не удалось загрузить уроки: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.entry, required this.index});

  final LessonEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final lesson = entry.lesson;
    if (lesson == null) {
      final color = Theme.of(context).colorScheme.error;
      return ListTile(
        leading: Icon(Icons.error_outline, color: color),
        title: Text('Ошибка в уроке', style: TextStyle(color: color)),
        subtitle: Text('${entry.error}'),
      );
    }
    return ListTile(
      leading: CircleAvatar(child: Text('${index + 1}')),
      title: Text(lesson.title),
      subtitle: Text(
        [
          if (lesson.description != null) lesson.description!,
          lessonStats(lesson),
        ].join('\n'),
      ),
      isThreeLine: lesson.description != null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LessonScreen(lesson: lesson)),
      ),
    );
  }
}

/// "70 BPM · 11 нот · 0:22"
String lessonStats(Lesson lesson) {
  final total = lesson.lengthInSeconds.round();
  final time = '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  final n = lesson.notes.length;
  return '${lesson.bpm.round()} BPM · $n ${ruPlural(n, 'нота', 'ноты', 'нот')} · $time';
}

/// Russian plural form: 1 нота, 2 ноты, 5 нот, 21 нота, 11 нот.
String ruPlural(int n, String one, String few, String many) {
  final mod100 = n % 100;
  final mod10 = n % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}
