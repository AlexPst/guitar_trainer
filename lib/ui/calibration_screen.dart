import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/mic_capture.dart';
import '../audio/isolate_note_event_source.dart';
import '../audio/soloud_metronome.dart';
import '../data/settings.dart';
import '../engine/calibration.dart';
import '../engine/metronome_scheduler.dart';
import '../engine/song_clock.dart';

enum _Stage { idle, running, done }

/// Measures latency: the player plucks on each click, we compare times.
///
/// Uses the same clock, metronome and note analysis as a lesson, so the
/// measured offset is exactly what scoring has to subtract.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  static const bpm = 90.0;
  static const countInBeats = 4;
  static const beats = 12;

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  static const _spb = 60 / CalibrationScreen.bpm;

  final _mic = MicCapture();
  SoloudMetronome? _metronome;
  IsolateNoteEventSource? _source;
  StreamSubscription<Object>? _micSub;
  StreamSubscription<Object>? _eventsSub;
  late final Ticker _ticker = createTicker(_tick);

  final _clock = SongClock();
  final _scheduler = MetronomeScheduler(
    const BeatGrid(_spb, 4),
    lastIndex: CalibrationScreen.beats - 1,
  );
  final _onsets = <double>[];

  _Stage _stage = _Stage.idle;
  String? _error;
  CalibrationResult? _result;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final settings = await ref
        .read(settingsProvider.future)
        .catchError((Object _) => Settings());
    try {
      _metronome = await SoloudMetronome.create()
        ..volume = settings.metronomeVolume;
      await _mic.start();
      final source = await IsolateNoteEventSource.spawn(
        sampleRate: _mic.sampleRate,
        minLevelDbfs: settings.micThresholdDbfs,
      );
      if (!mounted) {
        await source.dispose();
        return;
      }
      _source = source;
      _eventsSub = source.events.listen((events) {
        if (_stage != _Stage.running) return;
        for (final e in events) {
          if (e.onset) _onsets.add(e.time);
        }
      });
      _micSub = _mic.samples.listen(
        (chunk) => source.add(chunk, songTime: _clock.time),
      );
    } on Object catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() {});
  }

  void _start() {
    final m = _metronome;
    if (m == null) return;
    _onsets.clear();
    _result = null;
    _clock.start(-CalibrationScreen.countInBeats * _spb);
    m
      ..cancelPending()
      ..anchor(_clock.time, 1);
    _scheduler.reset(_clock.time);
    _scheduler.due(_clock.time).forEach(m.schedule);
    setState(() => _stage = _Stage.running);
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration _) {
    if (_stage != _Stage.running) return;
    _scheduler.due(_clock.time).forEach(_metronome!.schedule);
    // Wait past the last click for the last attack to arrive and be analysed.
    final end =
        (CalibrationScreen.beats - 1) * _spb + 0.4 + (_source?.delay ?? 0);
    if (_clock.time > end) {
      _clock.pause();
      _ticker.stop();
      final clicks = [
        for (var i = 0; i < CalibrationScreen.beats; i++) i * _spb,
      ];
      _result = estimateLatency(clicks, _onsets);
      _stage = _Stage.done;
    }
    setState(() {});
  }

  Future<void> _save() async {
    final r = _result;
    if (r == null) return;
    await ref
        .read(settingsProvider.notifier)
        .change((s) => s.copyWith(calibrationOffset: r.offset));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _micSub?.cancel();
    _eventsSub?.cancel();
    _source?.dispose();
    _mic.dispose();
    _metronome?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Калибровка задержки')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _error != null
                ? Text(
                    'Нужны микрофон и звук: $_error',
                    textAlign: TextAlign.center,
                  )
                : switch (_stage) {
                    _Stage.idle => _Intro(
                      ready: _metronome != null && _source != null,
                      onStart: _start,
                      text: text,
                    ),
                    _Stage.running => _Running(
                      time: _clock.time,
                      heard: _onsets.where((t) => t > -0.2).length,
                    ),
                    _Stage.done => _Done(
                      result: _result,
                      onRetry: _start,
                      onSave: _save,
                    ),
                  },
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({
    required this.ready,
    required this.onStart,
    required this.text,
  });

  final bool ready;
  final VoidCallback onStart;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer, size: 64),
        const SizedBox(height: 16),
        Text(
          'Прозвучат 4 щелчка отсчёта, затем ещё '
          '${CalibrationScreen.beats}. Щипайте любую открытую струну '
          'точно на каждый щелчок после отсчёта.',
          textAlign: TextAlign.center,
          style: text.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Лучше играть так, как будете заниматься: тот же микрофон, '
          'те же колонки или наушники.',
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Начать'),
          onPressed: ready ? onStart : null,
        ),
      ],
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({required this.time, required this.heard});

  final double time;
  final int heard;

  @override
  Widget build(BuildContext context) {
    const spb = 60 / CalibrationScreen.bpm;
    final beat = (time / spb).floor();
    final phase = time / spb - beat; // 0 right on the click
    final countIn = beat < 0;
    final label = countIn
        ? '${beat + CalibrationScreen.countInBeats + 1}'
        : '${(beat + 1).clamp(1, CalibrationScreen.beats)}';
    final pulse = 1 - phase.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(countIn ? 'Отсчёт…' : 'Играйте на щелчок'),
        const SizedBox(height: 24),
        Container(
          width: 120 + 60 * pulse,
          height: 120 + 60 * pulse,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (countIn ? Colors.grey : Colors.amber).withAlpha(
              (80 + 175 * pulse).round(),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        Text('Услышано атак: $heard'),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    required this.result,
    required this.onRetry,
    required this.onSave,
  });

  final CalibrationResult? result;
  final VoidCallback onRetry;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final text = Theme.of(context).textTheme;
    if (r == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hearing_disabled, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Не удалось измерить: услышано слишком мало атак. '
            'Поднесите гитару ближе к микрофону или увеличьте '
            'чувствительность в настройках.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      );
    }
    final ms = (r.offset * 1000).round();
    final spread = (r.spread * 1000).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Задержка', style: text.titleMedium),
        Text('$ms мс', style: text.displayMedium),
        Text(
          'разброс ±$spread мс · учтено ${r.matched} из '
          '${CalibrationScreen.beats} щелчков',
        ),
        if (spread > 40) ...[
          const SizedBox(height: 12),
          const Text(
            'Игра была неровной, результат может быть неточным. '
            'Попробуйте ещё раз.',
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          children: [
            FilledButton(onPressed: onSave, child: const Text('Сохранить')),
            OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ],
    );
  }
}
