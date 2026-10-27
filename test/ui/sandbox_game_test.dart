import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/game/sandbox_game.dart';
import 'package:guitar_trainer/ui/home_screen.dart';

void main() {
  testWithGame<SandboxGame>('sandbox game shows FPS text', SandboxGame.new, (
    game,
  ) async {
    await game.ready();
    expect(game.children.whereType<FpsTextComponent>(), hasLength(1));
  });

  testWidgets('home opens Flame screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.tap(find.text('Flame'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Flame'), findsOneWidget);
  });
}
