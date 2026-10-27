import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/level_meter.dart';
import '../audio/mic_providers.dart';

class MicTestScreen extends ConsumerWidget {
  const MicTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(micLevelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Проверка микрофона')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: switch (level) {
            AsyncData(:final value) => LevelBar(dbfs: value),
            AsyncError(:final error) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ошибка микрофона: $error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(micLevelProvider),
                  child: const Text('Повторить'),
                ),
              ],
            ),
            _ => const CircularProgressIndicator(),
          },
        ),
      ),
    );
  }
}

class LevelBar extends StatelessWidget {
  const LevelBar({super.key, required this.dbfs});

  final double dbfs;

  @override
  Widget build(BuildContext context) {
    final unit = dbfsToUnit(dbfs);
    final color = unit > 0.9
        ? Colors.red
        : unit > 0.6
        ? Colors.orange
        : Colors.green;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${dbfs.toStringAsFixed(1)} dBFS',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: unit,
            minHeight: 32,
            color: color,
          ),
        ),
        const SizedBox(height: 16),
        const Text('Скажите что-нибудь или сыграйте на гитаре'),
      ],
    );
  }
}
