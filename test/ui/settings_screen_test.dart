import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/data/progress_repository.dart';
import 'package:guitar_trainer/data/settings.dart';
import 'package:guitar_trainer/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  Future<void> open(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows current values', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings': '{"calibrationOffset":0.085,"hitWindow":0.15}',
    });
    await open(tester);
    expect(find.textContaining('Сейчас: 85 мс'), findsOneWidget);
    expect(find.textContaining('±150 мс'), findsOneWidget);
    expect(find.textContaining('порог -50 dBFS'), findsOneWidget);
  });

  testWidgets('left-handed switch is saved', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await open(tester);
    await tester.scrollUntilVisible(find.text('Для левши'), 200);
    await tester.tap(find.text('Для левши'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).value!.leftHanded, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings'), contains('"leftHanded":true'));
  });

  testWidgets('reset progress asks first, then clears', (tester) async {
    SharedPreferences.setMockInitialValues({
      'progress.a': '{"bestAccuracy":0.9,"bestScore":90,"stars":2}',
    });
    await open(tester);
    expect((await container.read(progressProvider.future)).keys, ['a']);

    await tester.scrollUntilVisible(find.text('Сбросить прогресс'), 200);
    await tester.tap(find.text('Сбросить прогресс'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect((await container.read(progressProvider.future)).keys, ['a']);

    await tester.tap(find.text('Сбросить прогресс'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Сбросить'));
    await tester.pumpAndSettle();
    expect(await container.read(progressProvider.future), isEmpty);
    expect(find.text('Прогресс сброшен'), findsOneWidget);
  });
}
