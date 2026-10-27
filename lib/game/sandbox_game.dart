import 'package:flame/components.dart';
import 'package:flame/game.dart';

/// Placeholder scene: proves Flame renders and shows FPS.
class SandboxGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    add(FpsTextComponent(position: Vector2(16, 16)));
  }
}
