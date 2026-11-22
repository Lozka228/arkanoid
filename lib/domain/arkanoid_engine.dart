import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import 'models.dart';

enum ArkanoidPhase { ready, playing, levelCleared, gameOver }

/// Игровая логика Арканоида. Не зависит от виджетов и от времени:
/// игровой цикл (Ticker) просто вызывает [update] с шагом dt.
class ArkanoidEngine extends ChangeNotifier {
  ArkanoidEngine({
    Random? random,
    double dropChance = 0.2,
    this.onEvent,
    this.maxBalls = defaultMaxBalls,
    this.speedMultiplier = 1.0,
    this.forcedDrop,
    this.multiplyAll = false,
  })  : dropChance = forcedDrop != null ? 1.0 : dropChance,
        _rng = random ?? Random() {
    _buildLevel();
    _resetBall();
  }

  static const double paddleY = 520;
  static const double paddleHeight = 14;
  static const double basePaddleWidth = 72;
  static const double widePaddleWidth = 112;
  static const double ballRadius = 7;
  static const int defaultMaxBalls = 5;
  static const double wideDuration = 10;
  static const double fastDuration = 8;
  static const double fastFactor = 1.5;
  static const double dropSpeed = 130;
  static const int startLives = 3;

  final Random _rng;

  /// Вероятность выпадения бонуса из разбитого кирпича.
  final double dropChance;

  /// Максимум мячей на поле.
  final int maxBalls;

  /// Множитель скорости мяча (2.0 — режим «двойная скорость»).
  final double speedMultiplier;

  /// Если задан — из каждого кирпича падает только этот бонус.
  final PowerUpType? forcedDrop;

  /// true — бонус «три мяча» утраивает все мячи, а не один.
  final bool multiplyAll;
  void Function(GameEvent event)? onEvent;

  ArkanoidPhase phase = ArkanoidPhase.ready;
  bool paused = false;
  int level = 1;
  int score = 0;
  int lives = startLives;
  int livesLostThisLevel = 0;

  double paddleX = kWorldW / 2;
  double paddleWidth = basePaddleWidth;
  double wideTimer = 0;
  double fastTimer = 0;

  final List<Brick> bricks = [];
  final List<Ball> balls = [];
  final List<PowerUp> powerUps = [];

  Rect get paddleRect => Rect.fromLTWH(
        paddleX - paddleWidth / 2,
        paddleY,
        paddleWidth,
        paddleHeight,
      );

  double get baseSpeed =>
      min(340.0 + (level - 1) * 18.0, 520.0) * speedMultiplier;

  // ---------- управление ----------

  void movePaddleTo(double x) {
    if (phase == ArkanoidPhase.gameOver || paused) return;
    _setPaddleX(x);
    for (final b in balls) {
      if (b.stuck) b.x = paddleX;
    }
    notifyListeners();
  }

  /// Сдвиг платформы на [dx] (относительное управление: палец может быть где угодно).
  void movePaddleBy(double dx) {
    movePaddleTo(paddleX + dx);
  }

  void launch() {
    if (phase != ArkanoidPhase.ready || paused) return;
    final a = (_rng.nextDouble() - 0.5) * 0.7; // ±0.35 рад от вертикали
    final s = baseSpeed;
    for (final b in balls) {
      if (b.stuck) {
        b.stuck = false;
        b.vx = s * sin(a);
        b.vy = -s * cos(a);
      }
    }
    phase = ArkanoidPhase.playing;
    notifyListeners();
  }

  void nextLevel() {
    if (phase != ArkanoidPhase.levelCleared) return;
    level++;
    livesLostThisLevel = 0;
    _clearBonuses();
    _buildLevel();
    _resetBall();
    phase = ArkanoidPhase.ready;
    notifyListeners();
  }

  void restart() {
    level = 1;
    score = 0;
    lives = startLives;
    livesLostThisLevel = 0;
    paused = false;
    paddleX = kWorldW / 2;
    _clearBonuses();
    _buildLevel();
    _resetBall();
    phase = ArkanoidPhase.ready;
    notifyListeners();
  }

  void pause() {
    if (!paused && phase != ArkanoidPhase.gameOver) {
      paused = true;
      notifyListeners();
    }
  }

  void resume() {
    if (paused) {
      paused = false;
      notifyListeners();
    }
  }

  // ---------- игровой цикл ----------

  void update(double dt) {
    if (paused || phase != ArkanoidPhase.playing) return;
    var remaining = dt.clamp(0.0, 0.05).toDouble();
    while (remaining > 1e-9 && phase == ArkanoidPhase.playing) {
      final h = min(remaining, 1 / 240);
      _step(h);
      remaining -= h;
    }
    notifyListeners();
  }

  void _step(double h) {
    if (wideTimer > 0) {
      wideTimer -= h;
      if (wideTimer <= 0) {
        wideTimer = 0;
        paddleWidth = basePaddleWidth;
        _setPaddleX(paddleX);
      }
    }
    if (fastTimer > 0) {
      fastTimer -= h;
      if (fastTimer <= 0) fastTimer = 0;
    }
    final k = fastTimer > 0 ? fastFactor : 1.0;

    for (final ball in List<Ball>.of(balls)) {
      _moveBall(ball, h * k);
    }
    balls.removeWhere((b) => b.y - b.radius > kWorldH);
    _updatePowerUps(h);

    if (bricks.isEmpty) {
      _clearLevel();
    } else if (balls.isEmpty) {
      _loseLife();
    }
  }

  void _moveBall(Ball b, double h) {
    b.x += b.vx * h;
    b.y += b.vy * h;
    final r = b.radius;

    if (b.x - r < 0) {
      b.x = r;
      b.vx = b.vx.abs();
    } else if (b.x + r > kWorldW) {
      b.x = kWorldW - r;
      b.vx = -b.vx.abs();
    }
    if (b.y - r < 0) {
      b.y = r;
      b.vy = b.vy.abs();
    }

    final p = paddleRect;
    if (b.vy > 0 &&
        b.y + r >= p.top &&
        b.y - r <= p.bottom &&
        b.x + r >= p.left &&
        b.x - r <= p.right) {
      final offset = ((b.x - paddleX) / (paddleWidth / 2)).clamp(-1.0, 1.0).toDouble();
      final speed = b.speed;
      final angle = offset * 1.05; // до ~60° от вертикали
      b.vx = speed * sin(angle);
      b.vy = -speed * cos(angle);
      b.y = p.top - r;
    }

    _collideBricks(b);
    _fixAngle(b);
  }

  void _collideBricks(Ball b) {
    Brick? hit;
    var best = double.infinity;
    var hitX = 0.0;
    var hitY = 0.0;
    for (final br in bricks) {
      final r = br.rect;
      final cx = b.x.clamp(r.left, r.right).toDouble();
      final cy = b.y.clamp(r.top, r.bottom).toDouble();
      final dx = b.x - cx;
      final dy = b.y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 <= b.radius * b.radius && d2 < best) {
        best = d2;
        hit = br;
        hitX = cx;
        hitY = cy;
      }
    }
    if (hit == null) return;

    if (best == 0) {
      // центр мяча внутри кирпича — просто разворачиваем по вертикали
      b.vy = -b.vy;
    } else {
      final dist = sqrt(best);
      final nx = (b.x - hitX) / dist;
      final ny = (b.y - hitY) / dist;
      b.x = hitX + nx * (b.radius + 0.01);
      b.y = hitY + ny * (b.radius + 0.01);
      final dot = b.vx * nx + b.vy * ny;
      if (dot < 0) {
        b.vx -= 2 * dot * nx;
        b.vy -= 2 * dot * ny;
      }
    }
    damageBrick(hit);
  }

  /// Не даёт мячу лететь почти горизонтально (иначе игра «зависает»).
  void _fixAngle(Ball b) {
    final s = b.speed;
    if (s == 0) return;
    final minVy = s * 0.25;
    if (b.vy.abs() < minVy) {
      final signY = b.vy <= 0 ? -1.0 : 1.0;
      final signX = b.vx < 0 ? -1.0 : 1.0;
      b.vy = signY * minVy;
      b.vx = signX * sqrt(max(0.0, s * s - minVy * minVy));
    }
  }

  /// Наносит кирпичу один удар; при гибели начисляет очки и может уронить бонус.
  void damageBrick(Brick br) {
    br.hp -= 1;
    if (br.hp > 0) {
      _addScore(5);
      return;
    }
    bricks.remove(br);
    _addScore(br.type.maxHp * 10);
    _emit(BrickDestroyed(br.type));
    if (_rng.nextDouble() < dropChance) {
      final t = forcedDrop ??
          PowerUpType.values[_rng.nextInt(PowerUpType.values.length)];
      powerUps.add(PowerUp(t, br.rect.center.dx, br.rect.center.dy));
    }
  }

  void _updatePowerUps(double h) {
    final p = paddleRect;
    for (final u in List<PowerUp>.of(powerUps)) {
      u.y += dropSpeed * h;
      if (u.rect.overlaps(p)) {
        powerUps.remove(u);
        applyPowerUp(u.type);
      } else if (u.y > kWorldH + 20) {
        powerUps.remove(u);
      }
    }
  }

  void applyPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.wide:
        paddleWidth = widePaddleWidth;
        wideTimer = wideDuration;
        _setPaddleX(paddleX);
      case PowerUpType.fast:
        fastTimer = fastDuration;
      case PowerUpType.multi:
        _splitBalls();
    }
    _emit(PowerUpCollected(type));
  }

  void _splitBalls() {
    final flying = balls.where((b) => !b.stuck).toList();
    if (flying.isEmpty) return;
    if (multiplyAll) {
      // каждый мяч превращается в три (в пределах maxBalls)
      for (final src in flying) {
        for (final sign in const [1.0, -1.0]) {
          if (balls.length >= maxBalls) break;
          balls.add(src.rotated(sign * (0.2 + _rng.nextDouble() * 0.5)));
        }
      }
    } else {
      final src = flying.first;
      for (final a in const [0.4, -0.4]) {
        if (balls.length >= maxBalls) break;
        balls.add(src.rotated(a));
      }
    }
    _emit(BallCountChanged(balls.length));
  }

  void _addScore(int v) {
    score += v;
    _emit(ScoreChanged(score));
  }

  void _clearLevel() {
    _addScore(100 * level);
    powerUps.clear();
    phase = ArkanoidPhase.levelCleared;
    _emit(LevelCleared(level, livesLostThisLevel == 0));
  }

  void _loseLife() {
    lives--;
    livesLostThisLevel++;
    _clearBonuses();
    _emit(LifeLost(lives));
    if (lives <= 0) {
      phase = ArkanoidPhase.gameOver;
      _emit(GameOver(score));
    } else {
      _resetBall();
      phase = ArkanoidPhase.ready;
    }
  }

  void _clearBonuses() {
    wideTimer = 0;
    fastTimer = 0;
    paddleWidth = basePaddleWidth;
    powerUps.clear();
    _setPaddleX(paddleX);
  }

  void _resetBall() {
    balls
      ..clear()
      ..add(Ball(
        x: paddleX,
        y: paddleY - ballRadius - 0.5,
        radius: ballRadius,
        stuck: true,
      ));
  }

  void _setPaddleX(double x) {
    paddleX = x.clamp(paddleWidth / 2, kWorldW - paddleWidth / 2).toDouble();
  }

  void _emit(GameEvent e) => onEvent?.call(e);

  // ---------- генерация уровней ----------

  void _buildLevel() {
    bricks.clear();
    const cols = 8;
    const margin = 12.0;
    const gap = 4.0;
    const bh = 18.0;
    const top = 56.0;
    final bw = (kWorldW - 2 * margin - (cols - 1) * gap) / cols;
    final rows = min(8, max(4, 3 + level));
    final pattern = (level - 1) % 4;
    final pGold = min(0.04 * (level - 1), 0.2);
    final pSilver = min(0.15 + 0.05 * (level - 1), 0.4);

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (!_include(pattern, r, c)) continue;
        final roll = _rng.nextDouble();
        final type = roll < pGold
            ? BrickType.gold
            : (roll < pGold + pSilver ? BrickType.silver : BrickType.normal);
        bricks.add(Brick(
          Rect.fromLTWH(margin + c * (bw + gap), top + r * (bh + gap), bw, bh),
          type,
          row: r,
        ));
      }
    }
  }

  bool _include(int pattern, int r, int c) {
    switch (pattern) {
      case 1: // шахматная доска
        return (r + c) % 2 == 0;
      case 2: // «коридор» в центре
        return !((c == 3 || c == 4) && r >= 2 && r % 2 == 0);
      case 3: // перевёрнутая пирамида
        return (c - 3.5).abs() + r * 0.5 <= 4.5;
      default: // сплошной прямоугольник
        return true;
    }
  }
}
