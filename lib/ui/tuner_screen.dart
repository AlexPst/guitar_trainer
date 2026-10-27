import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/mic_providers.dart';
import '../music/pitch.dart';
import '../music/tuner_reading.dart';

class TunerScreen extends ConsumerWidget {
  const TunerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref.watch(tunerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Тюнер')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: switch (reading) {
            AsyncData(:final value) => TunerView(reading: value),
            AsyncError(:final error) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ошибка микрофона: $error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(tunerProvider),
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

class TunerView extends StatelessWidget {
  const TunerView({super.key, required this.reading});

  final TunerReading? reading;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final text = Theme.of(context).textTheme;
    final color = r == null
        ? Theme.of(context).disabledColor
        : r.inTune
        ? Colors.green
        : Colors.orange;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          r?.note.name ?? '—',
          style: text.displayLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          r == null
              ? 'Сыграйте открытую струну'
              : '${r.string} струна (${midiName(r.stringMidi)}) · '
                    '${r.frequency.toStringAsFixed(1)} Гц',
          style: text.titleMedium,
        ),
        const SizedBox(height: 32),
        CentsMeter(cents: r?.note.cents, color: color),
        const SizedBox(height: 16),
        Text(
          r == null
              ? ' '
              : r.inTune
              ? 'В строю'
              : '${r.note.cents > 0 ? '+' : ''}'
                    '${r.note.cents.toStringAsFixed(0)} центов',
          style: text.headlineSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Horizontal scale from -50 to +50 cents with a moving needle.
class CentsMeter extends StatelessWidget {
  const CentsMeter({super.key, required this.cents, required this.color});

  final double? cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final inTuneWidth = TunerReading.inTuneCents / 50;
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(height: 2, color: outline),
          FractionallySizedBox(
            widthFactor: inTuneWidth,
            child: Container(height: 24, color: Colors.green.withAlpha(60)),
          ),
          for (final c in [-50, -25, 0, 25, 50])
            Align(
              alignment: Alignment(c / 50, 0),
              child: Container(
                width: 2,
                height: c == 0 ? 32 : 16,
                color: outline,
              ),
            ),
          if (cents != null)
            AnimatedAlign(
              duration: const Duration(milliseconds: 80),
              alignment: Alignment((cents! / 50).clamp(-1.0, 1.0), 0),
              child: Container(
                width: 6,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
