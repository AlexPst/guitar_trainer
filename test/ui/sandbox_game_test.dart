import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/game/sandbox_game.dart';

void main() {
  testWithGame<SandboxGame>('sandbox game shows FPS text', SandboxGame.new, (
    game,
  ) async {
    await game.ready();
    expect(game.children.whereType<FpsTextComponent>(), hasLength(1));
  });
}
