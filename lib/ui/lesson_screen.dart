import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/mic_capture.dart';
import '../audio/note_event_source.dart';
import '../audio/soloud_metronome.dart';
import '../data/progress_repository.dart';
import '../data/settings.dart';
import '../engine/lesson_playback.dart';
import '../game/lesson_game.dart';
import '../music/lesson.dart';
import 'lesson_overlays.dart';
import 'result_screen.dart';

/// Game screen of one lesson. Forces landscape on phones while open.
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({
    super.key,
    required this.lesson,
    this.initialMode = LessonMode.tempo,
    this.initialSpeed = 1,
  });

  final Lesson lesson;
  final LessonMode initialMode;
  final double initialSpeed;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  SoloudMetronome? _metronome;
  LessonGame? _game;
  final _mic = MicCapture();
  NoteEventSource? _source;
  StreamSubscription<Object>? _micSub;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _init();
  }

  Future<void> _init() async {
    // Each part may fail on its own; the lesson still runs without it, and
    // the user is told what is missing.
    final problems = <String>[];
    // Settings that fail to load fall back to defaults.
    final settings = await ref
        .read(settingsProvider.future)
        .catchError((Object _) => Settings());
    try {
      _metronome = await SoloudMetronome.create()
        ..volume = settings.metronomeVolume;
    } on Object catch (e) {
      problems.add('Метроном недоступен: $e');
    }
    if (!mounted) return;
    final game = LessonGame(
      lesson: widget.lesson,
      metronome: _metronome,
      mode: widget.initialMode,
      speed: widget.initialSpeed,
      calibrationOffset: settings.calibrationOffset,
      hitWindow: settings.hitWindow,
      leftHanded: settings.leftHanded,
    );
    game.phase.addListener(() {
      if (game.phase.value == PlaybackPhase.finished) _onFinished(game);
    });
    setState(() => _game = game);

    try {
      await _mic.start();
      final source = NoteEventSource(
        sampleRate: _mic.sampleRate,
        minLevelDbfs: settings.micThresholdDbfs,
      );
      _source = source;
      // Events lag the sound by the analysis delay plus one mic chunk.
      game.inputLag = source.delay + 0.05;
      _micSub = _mic.samples.listen((chunk) {
        final events = source.add(
          chunk,
          songTime: game.playback.time,
          speed: game.playback.speed,
        );
        if (events.isNotEmpty) game.addNoteEvents(events);
      });
    } on Object catch (e) {
      problems.add('Микрофон недоступен, ноты не оцениваются: $e');
    }
    if (!mounted) return;
    for (final p in problems) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p)));
    }
  }

  @override
  void dispose() {
    _micSub?.cancel();
    _mic.dispose();
    _source?.reset();
    _metronome?.dispose();
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exit() => Navigator.of(context).pop();

  bool _finishing = false;

  Future<void> _onFinished(LessonGame game) async {
    if (_finishing) return;
    _finishing = true;
    final result = game.result();
    final outcome = await ref.read(progressProvider.notifier).record(result);
    // Let the last hit effects play out before leaving.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          result: result,
          isNewBest: outcome == RecordOutcome.improved,
          mode: game.mode,
          speed: game.playback.speed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      backgroundColor: Colors.black,
      body: game == null
          ? const Center(child: CircularProgressIndicator())
          : GameWidget(
              game: game,
              initialActiveOverlays: const [Overlays.hud, Overlays.menu],
              overlayBuilderMap: {
                Overlays.hud: (_, LessonGame g) => LessonHud(game: g),
                Overlays.menu: (_, LessonGame g) =>
                    LessonMenu(game: g, onExit: _exit),
              },
            ),
    );
  }
}
