import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/level_meter.dart';
import '../audio/mic_providers.dart';
import '../data/settings.dart';
import 'calibration_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: switch (settings) {
        AsyncData(:final value) => _SettingsList(settings: value),
        AsyncError(:final error) => Center(
          child: Text('Не удалось загрузить настройки: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SettingsList extends ConsumerStatefulWidget {
  const _SettingsList({required this.settings});

  final Settings settings;

  @override
  ConsumerState<_SettingsList> createState() => _SettingsListState();
}

class _SettingsListState extends ConsumerState<_SettingsList> {
  bool _listening = false;

  Settings get s => widget.settings;

  void _change(Settings Function(Settings) edit) =>
      ref.read(settingsProvider.notifier).change(edit);

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить прогресс?'),
        content: const Text(
          'Все звёзды и лучшие результаты будут удалены, '
          'уроки снова закроются. Это нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await resetProgress(ref);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Прогресс сброшен')));
  }

  @override
  Widget build(BuildContext context) {
    final ms = (s.calibrationOffset * 1000).round();
    return ListView(
      children: [
        const _Header('Задержка'),
        ListTile(
          leading: const Icon(Icons.timer),
          title: const Text('Калибровка'),
          subtitle: Text(
            'Сейчас: $ms мс. Сыграйте под щелчки, чтобы измерить задержку '
            'микрофона и звука.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CalibrationScreen()),
          ),
        ),
        _SliderTile(
          title: 'Поправка вручную',
          valueText: '$ms мс',
          value: s.calibrationOffset,
          min: Settings.minCalibration,
          max: Settings.maxCalibration,
          divisions: 120,
          onChanged: (v) => _change((x) => x.copyWith(calibrationOffset: v)),
        ),

        const _Header('Микрофон'),
        _SliderTile(
          title: 'Чувствительность',
          valueText:
              '${(s.micSensitivity * 100).round()}% · порог '
              '${s.micThresholdDbfs.round()} dBFS',
          value: s.micSensitivity,
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: (v) => _change((x) => x.copyWith(micSensitivity: v)),
        ),
        SwitchListTile(
          title: const Text('Показать уровень микрофона'),
          subtitle: const Text(
            'Звук гитары должен заходить за отметку порога, тишина — нет.',
          ),
          value: _listening,
          onChanged: (v) => setState(() => _listening = v),
        ),
        if (_listening) _LevelWithThreshold(thresholdDbfs: s.micThresholdDbfs),

        const _Header('Метроном и оценка'),
        _SliderTile(
          title: 'Громкость метронома',
          valueText: '${(s.metronomeVolume * 100).round()}%',
          value: s.metronomeVolume,
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: (v) => _change((x) => x.copyWith(metronomeVolume: v)),
        ),
        _SliderTile(
          title: 'Окно попадания',
          valueText:
              '±${(s.hitWindow * 1000).round()} мс '
              '(${s.hitWindow < 0.1
                  ? 'строго'
                  : s.hitWindow > 0.15
                  ? 'мягко'
                  : 'обычно'})',
          value: s.hitWindow,
          min: Settings.minHitWindow,
          max: Settings.maxHitWindow,
          divisions: 14,
          onChanged: (v) => _change((x) => x.copyWith(hitWindow: v)),
        ),

        const _Header('Вид'),
        SwitchListTile(
          title: const Text('Для левши'),
          subtitle: const Text(
            'Зеркальная табулатура: линия удара справа, ноты едут слева.',
          ),
          value: s.leftHanded,
          onChanged: (v) => _change((x) => x.copyWith(leftHanded: v)),
        ),

        const _Header('Прогресс'),
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Сбросить прогресс'),
          subtitle: const Text('Удалить звёзды и лучшие результаты'),
          onTap: _confirmReset,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Text(valueText, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Live mic level with a mark where the silence threshold is.
class _LevelWithThreshold extends ConsumerWidget {
  const _LevelWithThreshold({required this.thresholdDbfs});

  final double thresholdDbfs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(micLevelProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: switch (level) {
        AsyncError(:final error) => Text('Микрофон недоступен: $error'),
        AsyncData(:final value) => LayoutBuilder(
          builder: (context, c) {
            final above = value >= thresholdDbfs;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: dbfsToUnit(value),
                        minHeight: 20,
                        color: above ? Colors.green : Colors.grey,
                      ),
                    ),
                    Positioned(
                      left: c.maxWidth * dbfsToUnit(thresholdDbfs) - 1,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 3, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${value.toStringAsFixed(0)} dBFS · '
                  '${above ? 'слышно' : 'тишина'}',
                ),
              ],
            );
          },
        ),
        _ => const LinearProgressIndicator(),
      },
    );
  }
}
