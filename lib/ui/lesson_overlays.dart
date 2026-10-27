import 'package:flutter/material.dart';

import '../engine/lesson_playback.dart';
import '../engine/song_clock.dart';
import '../game/lesson_game.dart';

/// Top bar over the game: title, tempo, progress and pause button.
class LessonHud extends StatelessWidget {
  const LessonHud({super.key, required this.game});

  final LessonGame game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        game.phase,
        game.modeNotifier,
        game.pass,
        game.lastPassAccuracy,
      ]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) => Text(
                      game.loop
                          ? _loopTitle(game)
                          : game.mode == LessonMode.wait
                          ? '${game.lesson.title} · ожидание'
                          : '${game.lesson.title} · '
                                '${(game.lesson.bpm * game.playback.speed).round()} BPM'
                                '${game.playback.speed < 1 ? ' (${(game.playback.speed * 100).round()}%)' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder(
                    valueListenable: game.progress,
                    builder: (context, value, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        color: Colors.amber,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _ScoreBox(game: game),
            const SizedBox(width: 12),
            _HeardNote(game: game),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              tooltip: 'Пауза',
              icon: const Icon(Icons.pause),
              onPressed: game.pause,
            ),
          ],
        ),
      ),
    );
  }
}

/// Start / pause menu with tempo control.
class LessonMenu extends StatefulWidget {
  const LessonMenu({
    super.key,
    required this.game,
    required this.onExit,
    this.onPracticeFragment,
  });

  final LessonGame game;
  final VoidCallback onExit;

  /// Opens loop practice of the chosen bars; null hides the button.
  final void Function(int fromBar, int toBar)? onPracticeFragment;

  @override
  State<LessonMenu> createState() => _LessonMenuState();
}

class _LessonMenuState extends State<LessonMenu> {
  LessonGame get game => widget.game;

  Future<void> _pickFragment() async {
    final bars = game.lesson.barCount;
    final picked = await showDialog<RangeValues>(
      context: context,
      builder: (context) => _FragmentDialog(bars: bars),
    );
    if (picked == null) return;
    widget.onPracticeFragment!(picked.start.round(), picked.end.round());
  }

  @override
  Widget build(BuildContext context) {
    final ready = game.playback.phase == PlaybackPhase.ready;
    final percent = (game.playback.speed * 100).round();
    return _Panel(
      children: [
        Text(
          ready ? game.lesson.title : 'Пауза',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (game.loop) ...[
          const Text(
            'Фрагмент повторяется по кругу. Темп растёт после чистого '
            'прохода (90%+) и снижается после трудного (меньше 60%).',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
        if (ready && !game.loop) ...[
          SegmentedButton<LessonMode>(
            segments: const [
              ButtonSegment(value: LessonMode.tempo, label: Text('В темпе')),
              ButtonSegment(value: LessonMode.wait, label: Text('Ожидание')),
            ],
            selected: {game.mode},
            onSelectionChanged: (s) => setState(() => game.setMode(s.single)),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Темп: $percent% · ${(game.lesson.bpm * game.playback.speed).round()} BPM',
        ),
        Slider(
          value: game.playback.speed,
          min: SongClock.minSpeed,
          max: SongClock.maxSpeed,
          divisions: 10,
          label: '$percent%',
          onChanged: (v) => setState(() => game.setSpeed(v)),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: Text(ready ? 'Старт' : 'Продолжить'),
          onPressed: ready ? game.start : game.resume,
        ),
        if (!ready) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.replay),
            label: const Text('Начать заново'),
            onPressed: game.start,
          ),
        ],
        if (ready && widget.onPracticeFragment != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.repeat),
            label: const Text('Отработать фрагмент…'),
            onPressed: _pickFragment,
          ),
        ],
        const SizedBox(height: 8),
        TextButton(onPressed: widget.onExit, child: const Text('Выйти')),
      ],
    );
  }
}

class _FragmentDialog extends StatefulWidget {
  const _FragmentDialog({required this.bars});

  final int bars;

  @override
  State<_FragmentDialog> createState() => _FragmentDialogState();
}

class _FragmentDialogState extends State<_FragmentDialog> {
  late RangeValues _range = RangeValues(1, widget.bars < 2 ? 1 : 2);

  @override
  Widget build(BuildContext context) {
    final from = _range.start.round();
    final to = _range.end.round();
    return AlertDialog(
      title: const Text('Какие такты отработать?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(from == to ? 'Такт $from' : 'Такты $from–$to'),
          if (widget.bars > 1)
            RangeSlider(
              values: _range,
              min: 1,
              max: widget.bars.toDouble(),
              divisions: widget.bars - 1,
              labels: RangeLabels('$from', '$to'),
              onChanged: (v) => setState(() => _range = v),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _range),
          child: const Text('Начать'),
        ),
      ],
    );
  }
}

String _loopTitle(LessonGame game) {
  final last = game.lastPassAccuracy.value;
  return '${game.lesson.title} · проход ${game.pass.value}'
      '${last == null ? '' : ' · прошлый ${(last * 100).round()}%'}'
      ' · темп ${(game.playback.speed * 100).round()}%';
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          // Scrolls on short landscape phone screens.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Score and combo in tempo mode.
class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.game});

  final LessonGame game;

  @override
  Widget build(BuildContext context) {
    if (game.mode == LessonMode.wait) return const SizedBox.shrink();
    const style = TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
    return ListenableBuilder(
      listenable: Listenable.merge([game.score, game.combo]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${game.score.value}', style: style.copyWith(fontSize: 24)),
          Text(
            game.combo.value >= 2 ? 'серия ×${game.combo.value}' : ' ',
            style: style.copyWith(color: Colors.amber, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// The note the microphone hears right now.
class _HeardNote extends StatelessWidget {
  const _HeardNote({required this.game});

  final LessonGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: game.heard,
      builder: (context, name, _) => Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hearing, color: Colors.white54, size: 16),
            Text(
              name ?? '—',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
