import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/soloud_metronome.dart';
import '../game/lesson_game.dart';
import '../music/lesson.dart';
import 'lesson_overlays.dart';

/// Game screen of one lesson. Forces landscape on phones while open.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  SoloudMetronome? _metronome;
  LessonGame? _game;
  String? _audioError;

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
    try {
      _metronome = await SoloudMetronome.create();
    } on Object catch (e) {
      // The lesson still works without clicks; tell the user why it's silent.
      _audioError = '$e';
    }
    if (!mounted) return;
    setState(() {
      _game = LessonGame(lesson: widget.lesson, metronome: _metronome);
    });
    if (_audioError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Метроном недоступен: $_audioError')),
      );
    }
  }

  @override
  void dispose() {
    _metronome?.dispose();
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exit() => Navigator.of(context).pop();

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
                Overlays.finished: (_, LessonGame g) =>
                    LessonFinished(game: g, onExit: _exit),
              },
            ),
    );
  }
}
