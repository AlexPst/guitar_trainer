import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/data/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults', () {
    final s = Settings();
    expect(s.calibrationOffset, 0);
    expect(s.hitWindow, 0.12);
    expect(s.micThresholdDbfs, -50);
    expect(s.leftHanded, isFalse);
  });

  test('values are clamped', () {
    final s = Settings(
      calibrationOffset: 2,
      micSensitivity: -1,
      metronomeVolume: 5,
      hitWindow: 0.01,
    );
    expect(s.calibrationOffset, Settings.maxCalibration);
    expect(s.micSensitivity, 0);
    expect(s.micThresholdDbfs, -35);
    expect(s.metronomeVolume, 1);
    expect(s.hitWindow, Settings.minHitWindow);
  });

  test('json round trip and missing keys', () {
    final s = Settings(
      calibrationOffset: 0.085,
      micSensitivity: 1,
      metronomeVolume: 0.3,
      hitWindow: 0.15,
      leftHanded: true,
    );
    final back = Settings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
    expect(back.micThresholdDbfs, -65);
    expect(Settings.fromJson({}).toJson(), Settings().toJson());
  });

  test('repository: defaults when empty or corrupt, saves', () async {
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.load().toJson(), Settings().toJson());
    await repo.save(Settings(leftHanded: true));
    expect(repo.load().leftHanded, isTrue);

    SharedPreferences.setMockInitialValues({'settings': '{oops'});
    final bad = SettingsRepository(await SharedPreferences.getInstance());
    expect(bad.load().toJson(), Settings().toJson());
  });

  test('notifier change is persisted', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    await c
        .read(settingsProvider.notifier)
        .change((s) => s.copyWith(calibrationOffset: 0.1));
    expect(c.read(settingsProvider).value!.calibrationOffset, 0.1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings'), contains('0.1'));
  });
}
