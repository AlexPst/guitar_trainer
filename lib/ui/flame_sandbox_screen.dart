import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/sandbox_game.dart';

class FlameSandboxScreen extends StatefulWidget {
  const FlameSandboxScreen({super.key});

  @override
  State<FlameSandboxScreen> createState() => _FlameSandboxScreenState();
}

class _FlameSandboxScreenState extends State<FlameSandboxScreen> {
  final _game = SandboxGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flame')),
      body: GameWidget(game: _game),
    );
  }
}
