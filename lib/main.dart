import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: GuitarTrainerApp()));
}

class GuitarTrainerApp extends StatelessWidget {
  const GuitarTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Гитарный тренажёр',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange),
      home: const HomeScreen(),
    );
  }
}
