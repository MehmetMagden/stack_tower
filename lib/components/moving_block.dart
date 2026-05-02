import 'package:flame/components.dart';
import '../game/stack_tower_game.dart';

class MovingBlock extends SpriteComponent with HasGameReference<StackTowerGame> {
  double speed; 
  int direction = 1; 
  bool moving = true;

  MovingBlock({
    required Sprite sprite, 
    required double y, 
    required double w, 
    required double h, 
    required double x, 
    required this.speed,
  }) : super(sprite: sprite, position: Vector2(x, y), size: Vector2(w, h));

  @override
  void update(double dt) {
    super.update(dt);
    if (!moving) return;
    if (game.windActive) position.x += game.windStrength * dt;
    
    position.x += speed * dt;

    if (position.x + size.x >= game.size.x) { 
      position.x = game.size.x - size.x; 
      speed = -speed.abs(); // Kesinlikle sola dön
    } 
    else if (position.x <= 0) { 
      position.x = 0; 
      speed = speed.abs(); // Kesinlikle sağa dön
    }
  }
}
