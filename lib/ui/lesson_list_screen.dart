import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lesson_repository.dart';
import '../data/progress_repository.dart';
import '../music/lesson.dart';
import 'flame_sandbox_screen.dart';
import 'lesson_screen.dart';
import 'mic_test_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';
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
    // Progress that failed to load just shows as "nothing played yet".
    final progress = ref.watch(progressProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уроки'),
        actions: [
          IconButton(
            tooltip: 'Тюнер',
            icon: const Icon(Icons.tune),
            onPressed: () => open(const TunerScreen()),
          ),
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings),
            onPressed: () => open(const SettingsScreen()),
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
        AsyncData(:final value) => _buildList(value, progress),
        AsyncError(:final error) => Center(
          child: Text('Не удалось загрузить уроки: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

Widget _buildList(
  List<LessonEntry> entries,
  Map<String, LessonProgress> progress,
) {
  // Broken files are skipped when deciding what the "previous lesson" is.
  final ids = [
    for (final e in entries)
      if (e.lesson != null) e.lesson!.id,
  ];
  final flags = unlockedFlags(ids, progress);
  final unlocked = {for (var i = 0; i < ids.length; i++) ids[i]: flags[i]};
  return ListView.separated(
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: entries.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, i) {
      final id = entries[i].lesson?.id;
      return _LessonTile(
        entry: entries[i],
        index: i,
        progress: progress[id],
        unlocked: unlocked[id] ?? false,
      );
    },
  );
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.entry,
    required this.index,
    required this.progress,
    required this.unlocked,
  });

  final LessonEntry entry;
  final int index;
  final LessonProgress? progress;
  final bool unlocked;

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
    final p = progress;
    return ListTile(
      // Locked lessons look disabled but still explain themselves on tap.
      textColor: unlocked ? null : Theme.of(context).disabledColor,
      iconColor: unlocked ? null : Theme.of(context).disabledColor,
      leading: CircleAvatar(
        child: unlocked ? Text('${index + 1}') : const Icon(Icons.lock),
      ),
      title: Text(lesson.title),
      trailing: p == null
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StarsRow(stars: p.stars, size: 18),
                Text('${(p.bestAccuracy * 100).round()}%'),
              ],
            ),
      subtitle: Text(
        [
          if (lesson.description != null) lesson.description!,
          lessonStats(lesson),
        ].join('\n'),
      ),
      isThreeLine: lesson.description != null,
      onTap: unlocked
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LessonScreen(lesson: lesson),
              ),
            )
          : () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text(
                    'Получите хотя бы одну звезду в предыдущем уроке',
                  ),
                ),
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
