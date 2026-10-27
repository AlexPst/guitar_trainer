import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lesson_repository.dart';
import '../data/progress_repository.dart';
import '../engine/lesson_result.dart';
import '../engine/note_result.dart';
import '../engine/practice.dart';
import '../game/feedback.dart';
import '../game/lesson_game.dart';
import '../music/lesson.dart';
import '../music/pitch.dart';
import 'lesson_screen.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({
    super.key,
    required this.result,
    required this.isNewBest,
    required this.mode,
    required this.speed,
  });

  final LessonResult result;
  final bool isNewBest;
  final LessonMode mode;
  final double speed;

  Lesson get lesson => result.lesson;

  /// The lesson after this one, if it exists and is unlocked.
  Lesson? _nextLesson(WidgetRef ref) {
    final lessons = ref.watch(lessonsProvider).value;
    final progress = ref.watch(progressProvider).value;
    if (lessons == null || progress == null) return null;
    final valid = [
      for (final e in lessons)
        if (e.lesson != null) e.lesson!,
    ];
    final i = valid.indexWhere((l) => l.id == lesson.id);
    if (i < 0 || i + 1 >= valid.length) return null;
    final unlocked = unlockedFlags([for (final l in valid) l.id], progress);
    return unlocked[i + 1] ? valid[i + 1] : null;
  }

  void _play(BuildContext context, Lesson l, {bool sameSettings = false}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LessonScreen(
          lesson: l,
          initialMode: sameSettings ? mode : LessonMode.tempo,
          initialSpeed: sameSettings ? speed : 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = _nextLesson(ref);
    final hard = result.scored && result.stars < 3 ? hardestBars(result) : null;
    final hardExcerpt = hard == null ? null : lesson.excerpt(hard.$1, hard.$2);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (result.scored) ...[
            StarsRow(stars: result.stars, size: 56, animate: true),
            const SizedBox(height: 8),
            // Counts up from 0 to the result.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: result.accuracy * 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                '${v.round()}%',
                textAlign: TextAlign.center,
                style: text.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isNewBest)
              Center(
                child: Chip(
                  avatar: const Icon(Icons.emoji_events, color: Colors.amber),
                  label: const Text('Новый рекорд!'),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Счёт ${result.score} · лучшая серия ${result.maxCombo}'
              '${speed < 1 ? ' · темп ${(speed * 100).round()}%' : ''}',
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            if (result.stars == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Для первой звезды нужно 60%. Попробуйте медленнее '
                  'или в режиме «Ожидание».',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
              ),
            const SizedBox(height: 16),
            _Counts(result: result),
            if (_tendency(result) case final t?) ...[
              const SizedBox(height: 12),
              Text(t, textAlign: TextAlign.center, style: text.bodyLarge),
            ],
          ] else ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 8),
            Text(
              'Все ${lesson.notes.length} нот сыграны',
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Режим «Ожидание» без счёта. Сыграйте в темпе, '
              'чтобы получить звёзды и открыть следующий урок.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.replay),
                label: const Text('Ещё раз'),
                onPressed: () => _play(context, lesson, sameSettings: true),
              ),
              if (hard != null && hardExcerpt != null)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.repeat),
                  label: Text(
                    hard.$1 == hard.$2
                        ? 'Отработать такт ${hard.$1}'
                        : 'Отработать такты ${hard.$1}–${hard.$2}',
                  ),
                  // Start slower than this run; the loop speeds up as it goes.
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => LessonScreen(
                        lesson: hardExcerpt,
                        loop: true,
                        initialSpeed: (speed - 0.25).clamp(0.5, 1.0),
                      ),
                    ),
                  ),
                ),
              if (next != null)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Следующий урок'),
                  onPressed: () => _play(context, next),
                ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('К списку'),
              ),
            ],
          ),
          if (result.scored && result.mistakes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Разбор ошибок', style: text.titleLarge),
            const SizedBox(height: 4),
            for (final r in result.mistakes) _MistakeTile(lesson, r),
          ],
        ],
      ),
    );
  }
}

String? _tendency(LessonResult r) {
  final mean = r.meanTiming;
  if (mean == null || r.playedCount < 3) return null;
  final ms = (mean * 1000).round();
  if (ms.abs() < 15) return 'Ритм ровный: в среднем ${ms.abs()} мс от доли.';
  return ms < 0
      ? 'В среднем вы спешите на ${-ms} мс.'
      : 'В среднем вы опаздываете на $ms мс.';
}

class StarsRow extends StatelessWidget {
  const StarsRow({
    super.key,
    required this.stars,
    this.size = 20,
    this.animate = false,
  });

  final int stars;
  final double size;

  /// Earned stars pop in one after another.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          if (animate && i < stars)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 500 + 300 * i),
              // Each star waits for the previous one, then bounces in.
              curve: Interval(
                (300 * i) / (500 + 300 * i),
                1,
                curve: Curves.elasticOut,
              ),
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Icon(Icons.star_rounded, color: Colors.amber, size: size),
            )
          else
            Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i < stars ? Colors.amber : Colors.grey,
              size: size,
            ),
      ],
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.result});

  final LessonResult result;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Точно', Judgement.hit, result.count(Judgement.hit)),
      (
        'Рано/поздно',
        Judgement.early,
        result.count(Judgement.early) + result.count(Judgement.late),
      ),
      ('Октава', Judgement.octave, result.count(Judgement.octave)),
      ('Не та нота', Judgement.wrongPitch, result.count(Judgement.wrongPitch)),
      ('Промах', Judgement.miss, result.count(Judgement.miss)),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, j, n) in items)
          Chip(
            avatar: CircleAvatar(backgroundColor: judgementColor(j)),
            label: Text('$label: $n'),
          ),
      ],
    );
  }
}

class _MistakeTile extends StatelessWidget {
  const _MistakeTile(this.lesson, this.result);

  final Lesson lesson;
  final NoteResult result;

  @override
  Widget build(BuildContext context) {
    final note = lesson.notes[result.noteIndex];
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: judgementColor(result.judgement),
        child: Text(
          '${note.fret}',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
      title: Text(
        '${notePosition(lesson, note)} · ${midiName(note.midi())} '
        '(${note.string} струна, ${note.fret} лад)',
      ),
      subtitle: Text(mistakeText(result)),
    );
  }
}

/// "такт 2, доля 3" (1-based; fractional beats as "3½" etc.).
String notePosition(Lesson lesson, TabNote note) {
  final perBar = lesson.timeSignature.beatsPerBar;
  final bar = note.beat ~/ perBar + 1;
  final inBar = note.beat - (bar - 1) * perBar + 1;
  final whole = inBar.floor();
  final frac = inBar - whole;
  final fracText = switch (frac) {
    0 => '',
    0.5 => '½',
    0.25 => '¼',
    0.75 => '¾',
    _ => '+${frac.toStringAsFixed(2)}',
  };
  return 'такт $bar, доля $whole$fracText';
}

String mistakeText(NoteResult r) {
  final ms = r.timingError == null ? null : (r.timingError! * 1000).round();
  final cents = r.cents?.round();
  return switch (r.judgement) {
    Judgement.hit => 'точно',
    Judgement.early => 'рано, $ms мс',
    Judgement.late => 'поздно, +$ms мс',
    Judgement.octave => 'та нота, но в другой октаве',
    Judgement.wrongPitch =>
      cents == null
          ? 'не та нота'
          : 'не та нота: ${cents > 0 ? '+' : ''}${(cents / 100).toStringAsFixed(1)} полутона',
    Judgement.miss => 'не сыграна',
  };
}
