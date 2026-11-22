import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../core/constants.dart';

enum FusePhase { ready, playing, gameOver }

/// Fuseball: мяч подчиняется гравитации, нужно подбрасывать его платформой
/// и попадать в единственный кирпич. После попадания появляется следующий.
class FuseballEngine extends ChangeNotifier {
  FuseballEngine({Random? random, this.onScore, this.onGameOver})
      : _rng = random ?? Random() {
    _spawnBrick();
  }

  static const double gravity = 1000;
  static const double bounceSpeed = 950;
  static const double ballRadius = 12;
  static const double paddleY = 520;
  static const double paddleHeight = 14;
  static const double paddleWidth = 96;
  static const double brickHeight = 24;
  static const double startY = 260;

  final Random _rng;
  void Function(int score)? onScore;
  void Function(int score)? onGameOver;

  FusePhase phase = FusePhase.ready;
  bool paused = false;
  int score = 0;
  double ballX = kWorldW / 2;
  double ballY = startY;
  double vx = 0;
  double vy = 0;
  double paddleX = kWorldW / 2;
  Rect brick = Rect.zero;

  Rect get paddleRect =>
      Rect.fromLTWH(paddleX - paddleWidth / 2, paddleY, paddleWidth, paddleHeight);

  /// Кирпич уменьшается с ростом счёта (минимум 52).
  double get brickWidth => max(52.0, 96.0 - score * 2.0);

  void movePaddleTo(double x) {
    if (phase == FusePhase.gameOver || paused) return;
    paddleX = x.clamp(paddleWidth / 2, kWorldW - paddleWidth / 2).toDouble();
    notifyListeners();
  }

  /// Сдвиг платформы на [dx] (относительное управление).
  void movePaddleBy(double dx) => movePaddleTo(paddleX + dx);

  void start() {
    if (phase != FusePhase.ready || paused) return;
    phase = FusePhase.playing;
    vx = (_rng.nextDouble() - 0.5) * 160;
    vy = 0;
    notifyListeners();
  }

  void restart() {
    score = 0;
    phase = FusePhase.ready;
    paused = false;
    ballX = kWorldW / 2;
    ballY = startY;
    vx = 0;
    vy = 0;
    _spawnBrick();
    notifyListeners();
  }

  void pause() {
    if (!paused && phase != FusePhase.gameOver) {
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

  void update(double dt) {
    if (paused || phase != FusePhase.playing) return;
    var remaining = dt.clamp(0.0, 0.05).toDouble();
    while (remaining > 1e-9 && phase == FusePhase.playing) {
      final h = min(remaining, 1 / 240);
      _step(h);
      remaining -= h;
    }
    notifyListeners();
  }

  void _step(double h) {
    vy += gravity * h;
    ballX += vx * h;
    ballY += vy * h;
    const r = ballRadius;

    if (ballX - r < 0) {
      ballX = r;
      vx = vx.abs();
    } else if (ballX + r > kWorldW) {
      ballX = kWorldW - r;
      vx = -vx.abs();
    }
    if (ballY - r < 0) {
      ballY = r;
      vy = vy.abs() * 0.6;
    }

    final p = paddleRect;
    if (vy > 0 &&
        ballY + r >= p.top &&
        ballY - r <= p.bottom &&
        ballX + r >= p.left &&
        ballX - r <= p.right) {
      final off = ((ballX - paddleX) / (paddleWidth / 2)).clamp(-1.0, 1.0).toDouble();
      vx = off * 340;
      vy = -bounceSpeed;
      ballY = p.top - r;
    }

    _collideBrick();

    if (ballY - r > kWorldH) {
      phase = FusePhase.gameOver;
      onGameOver?.call(score);
    }
  }

  void _collideBrick() {
    final cx = ballX.clamp(brick.left, brick.right).toDouble();
    final cy = ballY.clamp(brick.top, brick.bottom).toDouble();
    final dx = ballX - cx;
    final dy = ballY - cy;
    final d2 = dx * dx + dy * dy;
    if (d2 > ballRadius * ballRadius) return;

    if (d2 == 0) {
      vy = -vy;
    } else {
      final dist = sqrt(d2);
      final nx = dx / dist;
      final ny = dy / dist;
      ballX = cx + nx * (ballRadius + 0.01);
      ballY = cy + ny * (ballRadius + 0.01);
      final dot = vx * nx + vy * ny;
      if (dot < 0) {
        vx -= 2 * dot * nx * 0.9;
        vy -= 2 * dot * ny * 0.9;
      }
    }
    score++;
    onScore?.call(score);
    _spawnBrick();
  }

  void _spawnBrick() {
    final w = brickWidth;
    final prev = brick.center;
    var candidate = Rect.zero;
    for (var i = 0; i < 30; i++) {
      final x = 16 + _rng.nextDouble() * (kWorldW - 32 - w);
      final y = 110 + _rng.nextDouble() * 270;
      candidate = Rect.fromLTWH(x, y, w, brickHeight);
      if ((candidate.center - prev).distance > 110) break;
    }
    brick = candidate;
  }
}
