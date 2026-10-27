import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress_repository.dart';

enum AppTheme { system, light, dark }

/// User settings. Values are clamped to their ranges on creation.
class Settings {
  Settings({
    double calibrationOffset = 0,
    double micSensitivity = 0.5,
    double metronomeVolume = 0.8,
    double hitWindow = 0.12,
    this.leftHanded = false,
    this.theme = AppTheme.system,
  }) : calibrationOffset = calibrationOffset.clamp(
         minCalibration,
         maxCalibration,
       ),
       micSensitivity = micSensitivity.clamp(0.0, 1.0),
       metronomeVolume = metronomeVolume.clamp(0.0, 1.0),
       hitWindow = hitWindow.clamp(minHitWindow, maxHitWindow);

  factory Settings.fromJson(Map<String, Object?> json) {
    double read(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    return Settings(
      calibrationOffset: read('calibrationOffset', 0),
      micSensitivity: read('micSensitivity', 0.5),
      metronomeVolume: read('metronomeVolume', 0.8),
      hitWindow: read('hitWindow', 0.12),
      leftHanded: json['leftHanded'] == true,
      theme: AppTheme.values.asNameMap()[json['theme']] ?? AppTheme.system,
    );
  }

  static const minCalibration = -0.1;
  static const maxCalibration = 0.5;
  static const minHitWindow = 0.06;
  static const maxHitWindow = 0.2;

  /// Measured input + output latency, seconds; subtracted from event times.
  final double calibrationOffset;

  /// 0..1; higher hears quieter playing (and more noise).
  final double micSensitivity;

  /// 0..1.
  final double metronomeVolume;

  /// Half-width of the "in tempo" hit window, seconds.
  final double hitWindow;

  /// Mirror the tab: hit line on the right, notes moving left to right.
  final bool leftHanded;

  final AppTheme theme;

  /// Level below which the mic counts as silence: −35 dBFS at 0% up to
  /// −65 dBFS at 100% sensitivity (−50 by default).
  double get micThresholdDbfs => -35 - 30 * micSensitivity;

  Settings copyWith({
    double? calibrationOffset,
    double? micSensitivity,
    double? metronomeVolume,
    double? hitWindow,
    bool? leftHanded,
    AppTheme? theme,
  }) => Settings(
    calibrationOffset: calibrationOffset ?? this.calibrationOffset,
    micSensitivity: micSensitivity ?? this.micSensitivity,
    metronomeVolume: metronomeVolume ?? this.metronomeVolume,
    hitWindow: hitWindow ?? this.hitWindow,
    leftHanded: leftHanded ?? this.leftHanded,
    theme: theme ?? this.theme,
  );

  Map<String, Object?> toJson() => {
    'calibrationOffset': calibrationOffset,
    'micSensitivity': micSensitivity,
    'metronomeVolume': metronomeVolume,
    'hitWindow': hitWindow,
    'leftHanded': leftHanded,
    'theme': theme.name,
  };
}

class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _key = 'settings';
  final SharedPreferences _prefs;

  Settings load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return Settings();
    try {
      return Settings.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return Settings(); // corrupt: back to defaults
    }
  }

  Future<void> save(Settings s) =>
      _prefs.setString(_key, jsonEncode(s.toJson()));
}

final settingsRepositoryProvider = FutureProvider<SettingsRepository>(
  (ref) async => SettingsRepository(await SharedPreferences.getInstance()),
);

class SettingsNotifier extends AsyncNotifier<Settings> {
  @override
  Future<Settings> build() async =>
      (await ref.watch(settingsRepositoryProvider.future)).load();

  Future<void> change(Settings Function(Settings) edit) async {
    final repo = await ref.read(settingsRepositoryProvider.future);
    final next = edit(state.value ?? repo.load());
    state = AsyncData(next);
    await repo.save(next);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);

/// Deletes all saved lesson results.
Future<void> resetProgress(WidgetRef ref) async {
  final repo = await ref.read(progressRepositoryProvider.future);
  await repo.clear();
  ref.invalidate(progressProvider);
}
