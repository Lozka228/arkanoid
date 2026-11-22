import 'dart:math';
import 'dart:ui';

import 'package:arkanoid/core/constants.dart';
import 'package:arkanoid/domain/fuseball_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('гравитация: падающий мяч разгоняется вниз', () {
    final e = FuseballEngine(random: Random(2));
    e.phase = FusePhase.playing;
    e.vy = 0;
    e.update(0.05);
    expect(e.vy, greaterThan(0));
    expect(e.ballY, greaterThan(FuseballEngine.startY));
  });

  test('платформа подбрасывает мяч вверх', () {
    final e = FuseballEngine(random: Random(2));
    e.phase = FusePhase.playing;
    e.ballX = e.paddleX;
    e.ballY = FuseballEngine.paddleY - 40;
    e.vx = 0;
    e.vy = 0;
    var bounced = false;
    for (var i = 0; i < 30; i++) {
      e.update(1 / 60);
      if (e.vy < -900) bounced = true;
    }
    expect(bounced, isTrue);
  });

  test('попадание в кирпич: +1 очко и новый кирпич', () {
    final scores = <int>[];
    final e = FuseballEngine(random: Random(3), onScore: scores.add);
    final old = Rect.fromLTWH(160, 300, 40, 24);
    e.brick = old;
    e.phase = FusePhase.playing;
    e.ballX = 180;
    e.ballY = 340;
    e.vx = 0;
    e.vy = -400;
    e.update(0.05);
    expect(e.score, 1);
    expect(scores, [1]);
    expect(e.brick, isNot(old));
  });

  test('промах: мяч упал — игра окончена, вызван onGameOver', () {
    int? finalScore;
    final e = FuseballEngine(random: Random(2), onGameOver: (s) => finalScore = s);
    e.phase = FusePhase.playing;
    e.paddleX = 300;
    e.ballX = 50;
    e.ballY = 500;
    e.vx = 0;
    e.vy = 0;
    for (var i = 0; i < 90 && e.phase == FusePhase.playing; i++) {
      e.update(1 / 60);
    }
    expect(e.phase, FusePhase.gameOver);
    expect(finalScore, 0);
  });

  test('кирпич уменьшается с ростом счёта, но не меньше 52', () {
    final e = FuseballEngine(random: Random(2));
    expect(e.brickWidth, 96);
    e.score = 20;
    expect(e.brickWidth, 56);
    e.score = 100;
    expect(e.brickWidth, 52);
  });

  test('новый кирпич всегда в пределах поля', () {
    final e = FuseballEngine(random: Random(5));
    for (var i = 0; i < 50; i++) {
      e.restart();
      expect(e.brick.left, greaterThanOrEqualTo(0));
      expect(e.brick.right, lessThanOrEqualTo(kWorldW));
    }
  });
}
