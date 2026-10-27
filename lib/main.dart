import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/settings.dart';
import 'ui/lesson_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: GuitarTrainerApp()));
}

ThemeData _theme(Brightness brightness) => ThemeData(
  colorSchemeSeed: Colors.deepOrange,
  brightness: brightness,
  // Same transition on every platform: content slides in and fades.
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    },
  ),
);

class GuitarTrainerApp extends ConsumerWidget {
  const GuitarTrainerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider).value?.theme ?? AppTheme.system;
    return MaterialApp(
      title: 'Гитарный тренажёр',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: switch (theme) {
        AppTheme.system => ThemeMode.system,
        AppTheme.light => ThemeMode.light,
        AppTheme.dark => ThemeMode.dark,
      },
      home: const LessonListScreen(),
    );
  }
}
