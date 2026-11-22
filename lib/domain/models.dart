import 'dart:math';
import 'dart:ui' show Offset, Rect;

/// Тип кирпича: число ударов, нужное для разрушения («броня»).
enum BrickType {
  normal(1),
  silver(2),
  gold(3);

  const BrickType(this.maxHp);
  final int maxHp;
}

class Brick {
  Brick(this.rect, this.type, {this.row = 0}) : hp = type.maxHp;

  final Rect rect;
  final BrickType type;
  final int row;
  int hp;
}

class Ball {
  Ball({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.radius = 7,
    this.stuck = false,
  });

  double x;
  double y;
  double vx;
  double vy;
  final double radius;

  /// true — мяч «прилип» к платформе и ждёт запуска.
  bool stuck;

  double get speed => sqrt(vx * vx + vy * vy);

  /// Копия мяча с вектором скорости, повёрнутым на [angle] радиан.
  Ball rotated(double angle) {
    final c = cos(angle);
    final s = sin(angle);
    return Ball(
      x: x,
      y: y,
      vx: vx * c - vy * s,
      vy: vx * s + vy * c,
      radius: radius,
    );
  }
}

enum PowerUpType {
  wide('Широкая платформа'),
  multi('Три мяча'),
  fast('Ускорение мяча');

  const PowerUpType(this.title);
  final String title;
}

class PowerUp {
  PowerUp(this.type, this.x, this.y);

  static const double size = 26;
  final PowerUpType type;
  final double x;
  double y;

  Rect get rect => Rect.fromCenter(center: Offset(x, y), width: size, height: size);
}

/// События игры — на них подписываются достижения и экран.
sealed class GameEvent {
  const GameEvent();
}

class BrickDestroyed extends GameEvent {
  const BrickDestroyed(this.type);
  final BrickType type;
}

class PowerUpCollected extends GameEvent {
  const PowerUpCollected(this.type);
  final PowerUpType type;
}

class BallCountChanged extends GameEvent {
  const BallCountChanged(this.count);
  final int count;
}

class ScoreChanged extends GameEvent {
  const ScoreChanged(this.score);
  final int score;
}

class LifeLost extends GameEvent {
  const LifeLost(this.livesLeft);
  final int livesLeft;
}

class LevelCleared extends GameEvent {
  const LevelCleared(this.level, this.flawless);
  final int level;

  /// true — уровень пройден без потери жизней.
  final bool flawless;
}

class GameOver extends GameEvent {
  const GameOver(this.score);
  final int score;
}
