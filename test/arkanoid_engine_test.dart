import 'dart:math';
import 'dart:ui';

import 'package:arkanoid/core/constants.dart';
import 'package:arkanoid/domain/arkanoid_engine.dart';
import 'package:arkanoid/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

ArkanoidEngine make({double drop = 0, List<GameEvent>? events}) =>
    ArkanoidEngine(random: Random(1), dropChance: drop, onEvent: events?.add);

/// Ставит единственный летящий мяч и переводит игру в фазу playing.
Ball setBall(ArkanoidEngine e,
    {double x = 180, double y = 400, double vx = 0, double vy = -200}) {
  final ball = Ball(x: x, y: y, vx: vx, vy: vy);
  e.balls
    ..clear()
    ..add(ball);
  e.phase = ArkanoidPhase.playing;
  return ball;
}

void main() {
  group('Запуск и управление', () {
    test('launch(): мяч летит вверх, фаза playing', () {
      final e = make();
      e.launch();
      expect(e.phase, ArkanoidPhase.playing);
      expect(e.balls.single.stuck, isFalse);
      expect(e.balls.single.vy, lessThan(0));
    });

    test('платформа не выходит за границы поля', () {
      final e = make();
      e.movePaddleTo(-100);
      expect(e.paddleX, ArkanoidEngine.basePaddleWidth / 2);
      e.movePaddleTo(1000);
      expect(e.paddleX, kWorldW - ArkanoidEngine.basePaddleWidth / 2);
    });

    test('прилипший мяч следует за платформой', () {
      final e = make();
      e.movePaddleTo(100);
      expect(e.balls.single.x, 100);
    });

    test('на паузе мяч не двигается', () {
      final e = make();
      final b = setBall(e);
      e.pause();
      e.update(0.05);
      expect(b.y, 400);
      e.resume();
      e.update(0.05);
      expect(b.y, lessThan(400));
    });
  });

  group('Физика', () {
    test('отскок от левой стены', () {
      final e = make();
      final b = setBall(e, x: 8, y: 300, vx: -200, vy: -200);
      e.update(0.05);
      expect(b.vx, greaterThan(0));
    });

    test('удар по правой части платформы отправляет мяч вправо-вверх', () {
      final e = make();
      final b = setBall(e,
          x: e.paddleX + 30, y: ArkanoidEngine.paddleY - 10, vx: 0, vy: 300);
      e.update(0.02);
      expect(b.vy, lessThan(0));
      expect(b.vx, greaterThan(0));
    });

    test('мяч не летит горизонтально', () {
      final e = make();
      final b = setBall(e, x: 100, y: 300, vx: 300, vy: 0);
      e.update(0.016);
      expect(b.vy.abs(), greaterThan(0));
    });
  });

  group('Кирпичи', () {
    test('обычный кирпич разбивается с одного удара', () {
      final events = <GameEvent>[];
      final e = make(events: events);
      e.bricks
        ..clear()
        ..addAll([
          Brick(Rect.fromLTWH(160, 300, 40, 18), BrickType.normal),
          Brick(Rect.fromLTWH(10, 100, 40, 18), BrickType.normal),
        ]);
      setBall(e, x: 180, y: 330, vx: 0, vy: -300);
      for (var i = 0; i < 30; i++) {
        e.update(1 / 60);
      }
      expect(e.bricks.length, 1);
      expect(events.whereType<BrickDestroyed>().length, 1);
      expect(e.score, greaterThanOrEqualTo(10));
    });

    test('золотой кирпич держит три удара', () {
      final e = make();
      final gold = Brick(Rect.fromLTWH(0, 0, 40, 18), BrickType.gold);
      e.bricks.add(gold);
      e.damageBrick(gold);
      e.damageBrick(gold);
      expect(gold.hp, 1);
      expect(e.bricks.contains(gold), isTrue);
      e.damageBrick(gold);
      expect(e.bricks.contains(gold), isFalse);
      expect(e.score, 5 + 5 + 30);
    });

    test('серебряный кирпич держит два удара', () {
      final e = make();
      final silver = Brick(Rect.fromLTWH(0, 0, 40, 18), BrickType.silver);
      e.bricks.add(silver);
      e.damageBrick(silver);
      expect(e.bricks.contains(silver), isTrue);
      e.damageBrick(silver);
      expect(e.bricks.contains(silver), isFalse);
    });

    test('уровни генерируются в границах поля, с ростом появляется броня', () {
      final e = make();
      for (var n = 1; n <= 9; n++) {
        e.phase = ArkanoidPhase.levelCleared;
        e.nextLevel();
        expect(e.level, n + 1);
        expect(e.bricks, isNotEmpty);
        for (final b in e.bricks) {
          expect(b.rect.left, greaterThanOrEqualTo(0));
          expect(b.rect.right, lessThanOrEqualTo(kWorldW));
        }
      }
      expect(e.bricks.any((b) => b.type != BrickType.normal), isTrue);
    });
  });

  group('Бонусы', () {
    test('шанс выпадения 100% — бонус появляется', () {
      final e = make(drop: 1);
      final br = Brick(Rect.fromLTWH(50, 50, 40, 18), BrickType.normal);
      e.bricks.add(br);
      e.damageBrick(br);
      expect(e.powerUps.length, 1);
    });

    test('шанс выпадения 0% — бонусов нет', () {
      final e = make(drop: 0);
      final br = Brick(Rect.fromLTWH(50, 50, 40, 18), BrickType.normal);
      e.bricks.add(br);
      e.damageBrick(br);
      expect(e.powerUps, isEmpty);
    });

    test('«три мяча» даёт 3 мяча и событие, не больше 5', () {
      final events = <GameEvent>[];
      final e = make(events: events);
      setBall(e);
      e.applyPowerUp(PowerUpType.multi);
      expect(e.balls.length, 3);
      expect(events.whereType<BallCountChanged>().last.count, 3);
      e.applyPowerUp(PowerUpType.multi);
      e.applyPowerUp(PowerUpType.multi);
      expect(e.balls.length, ArkanoidEngine.defaultMaxBalls);
    });

    test('«широкая платформа» расширяет и по таймеру возвращается', () {
      final e = make();
      setBall(e, vx: 0, vy: 0); // неподвижный мяч, чтобы не мешал
      e.applyPowerUp(PowerUpType.wide);
      expect(e.paddleWidth, ArkanoidEngine.widePaddleWidth);
      for (var i = 0; i < 240; i++) {
        e.update(0.05); // 12 секунд
      }
      expect(e.paddleWidth, ArkanoidEngine.basePaddleWidth);
      expect(e.wideTimer, 0);
    });

    test('«ускорение» увеличивает скорость мяча в 1.5 раза', () {
      final fast = make();
      final normal = make();
      final bf = setBall(fast, vy: -200);
      final bn = setBall(normal, vy: -200);
      fast.applyPowerUp(PowerUpType.fast);
      fast.update(0.05);
      normal.update(0.05);
      expect(400 - bf.y, closeTo(15, 0.01));
      expect(400 - bn.y, closeTo(10, 0.01));
    });

    test('падающий бонус ловится платформой', () {
      final events = <GameEvent>[];
      final e = make(events: events);
      setBall(e, vx: 0, vy: 0);
      e.powerUps.add(PowerUp(PowerUpType.wide, e.paddleX, ArkanoidEngine.paddleY - 5));
      e.update(0.02);
      expect(e.powerUps, isEmpty);
      expect(events.whereType<PowerUpCollected>().length, 1);
    });
  });

  group('Extra-режимы', () {
    test('бесконечные мячи: множитель ×3 утраивает все мячи, максимум 100', () {
      final e = ArkanoidEngine(
        random: Random(1),
        maxBalls: 100,
        forcedDrop: PowerUpType.multi,
        multiplyAll: true,
      );
      setBall(e);
      e.applyPowerUp(PowerUpType.multi);
      expect(e.balls.length, 3);
      e.applyPowerUp(PowerUpType.multi);
      expect(e.balls.length, 9);
      for (var i = 0; i < 6; i++) {
        e.applyPowerUp(PowerUpType.multi);
      }
      expect(e.balls.length, 100);
    });

    test('бесконечные мячи: из каждого кирпича падает ×3', () {
      final e = ArkanoidEngine(
        random: Random(1),
        forcedDrop: PowerUpType.multi,
        multiplyAll: true,
      );
      for (var i = 0; i < 5; i++) {
        final br = Brick(Rect.fromLTWH(10.0 * i, 50, 8, 8), BrickType.normal);
        e.bricks.add(br);
        e.damageBrick(br);
      }
      expect(e.powerUps.length, 5);
      expect(e.powerUps.every((u) => u.type == PowerUpType.multi), isTrue);
    });

    test('двойная скорость: запуск вдвое быстрее обычного', () {
      final normal = make()..launch();
      final dbl = ArkanoidEngine(random: Random(1), speedMultiplier: 2.0)..launch();
      expect(dbl.balls.single.speed, closeTo(normal.balls.single.speed * 2, 0.01));
    });
  });

  group('Управление', () {
    test('movePaddleBy сдвигает платформу относительно текущего положения', () {
      final e = make();
      final x = e.paddleX;
      e.movePaddleBy(25);
      expect(e.paddleX, x + 25);
      e.movePaddleBy(-10);
      expect(e.paddleX, x + 15);
    });

    test('платформа расположена выше прежнего положения (520)', () {
      expect(ArkanoidEngine.paddleY, 520);
    });
  });

  group('Жизни и уровни', () {
    test('потеря мяча отнимает жизнь и возвращает в фазу ready', () {
      final events = <GameEvent>[];
      final e = make(events: events);
      setBall(e, x: 180, y: kWorldH + 50, vy: 100);
      e.update(0.016);
      expect(e.lives, 2);
      expect(e.phase, ArkanoidPhase.ready);
      expect(e.balls.single.stuck, isTrue);
      expect(events.whereType<LifeLost>().length, 1);
    });

    test('после трёх потерь — конец игры', () {
      final events = <GameEvent>[];
      final e = make(events: events);
      for (var i = 0; i < 3; i++) {
        setBall(e, x: 180, y: kWorldH + 50, vy: 100);
        e.update(0.016);
      }
      expect(e.lives, 0);
      expect(e.phase, ArkanoidPhase.gameOver);
      expect(events.whereType<GameOver>().length, 1);
    });

    test('уровень без потерь жизней: flawless = true', () {
      final events = <GameEvent>[];
      final e = make(events: events);
      e.bricks
        ..clear()
        ..add(Brick(Rect.fromLTWH(160, 300, 40, 18), BrickType.normal));
      setBall(e, x: 180, y: 330, vx: 0, vy: -300);
      for (var i = 0; i < 30; i++) {
        e.update(1 / 60);
      }
      expect(e.phase, ArkanoidPhase.levelCleared);
      final cleared = events.whereType<LevelCleared>().single;
      expect(cleared.level, 1);
      expect(cleared.flawless, isTrue);
      e.nextLevel();
      expect(e.level, 2);
      expect(e.phase, ArkanoidPhase.ready);
    });

    test('уровень с потерей жизни: flawless = false', () {
      final events = <GameEvent>[];
      final e = make(events: events);
      e.livesLostThisLevel = 1;
      e.bricks
        ..clear()
        ..add(Brick(Rect.fromLTWH(160, 300, 40, 18), BrickType.normal));
      setBall(e, x: 180, y: 330, vx: 0, vy: -300);
      for (var i = 0; i < 30; i++) {
        e.update(1 / 60);
      }
      expect(events.whereType<LevelCleared>().single.flawless, isFalse);
    });

    test('restart() сбрасывает игру', () {
      final e = make();
      e.score = 500;
      e.lives = 1;
      e.level = 4;
      e.restart();
      expect([e.score, e.lives, e.level], [0, 3, 1]);
      expect(e.phase, ArkanoidPhase.ready);
    });
  });
}
