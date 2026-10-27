import 'package:flutter/material.dart';

import 'flame_sandbox_screen.dart';
import 'mic_test_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: const Text('Гитарный тренажёр')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.mic),
              label: const Text('Проверка микрофона'),
              onPressed: () => open(const MicTestScreen()),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.videogame_asset),
              label: const Text('Flame'),
              onPressed: () => open(const FlameSandboxScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
