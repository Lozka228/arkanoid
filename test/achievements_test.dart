import 'package:arkanoid/data/game_repository.dart';
import 'package:arkanoid/data/game_storage.dart';
import 'package:arkanoid/domain/achievements.dart';
import 'package:arkanoid/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

AchievementService make(MemoryStorage s) => AchievementService(GameRepository(s));

void main() {
  test('«Разбить 100 блоков» открывается ровно на сотом блоке', () {
    final svc = make(MemoryStorage());
    final unlocked = <String>[];
    svc.onUnlocked = (a) => unlocked.add(a.id);
    for (var i = 0; i < 99; i++) {
      svc.handleArkanoidEvent(const BrickDestroyed(BrickType.normal));
    }
    expect(svc.isUnlocked('bricks100'), isFalse);
    expect(svc.progress(achievementList.first), closeTo(0.99, 1e-9));
    svc.handleArkanoidEvent(const BrickDestroyed(BrickType.normal));
    expect(svc.isUnlocked('bricks100'), isTrue);
    svc.handleArkanoidEvent(const BrickDestroyed(BrickType.normal));
    expect(unlocked, ['bricks100']); // повторного уведомления нет
  });

  test('бронированные кирпичи считаются отдельно', () {
    final svc = make(MemoryStorage());
    for (var i = 0; i < 25; i++) {
      svc.handleArkanoidEvent(const BrickDestroyed(BrickType.silver));
    }
    expect(svc.isUnlocked('armor25'), isTrue);
    expect(svc.isUnlocked('bricks100'), isFalse);
  });

  test('«Пройти уровень без потери жизней»', () {
    final a = make(MemoryStorage());
    a.handleArkanoidEvent(const LevelCleared(1, false));
    expect(a.isUnlocked('flawless'), isFalse);
    a.handleArkanoidEvent(const LevelCleared(2, true));
    expect(a.isUnlocked('flawless'), isTrue);
  });

  test('«Поймать 3 мяча одновременно»', () {
    final svc = make(MemoryStorage());
    svc.handleArkanoidEvent(const BallCountChanged(2));
    expect(svc.isUnlocked('triple'), isFalse);
    svc.handleArkanoidEvent(const BallCountChanged(3));
    expect(svc.isUnlocked('triple'), isTrue);
  });

  test('бонусы, очки, уровни и Fuseball', () {
    final svc = make(MemoryStorage());
    for (var i = 0; i < 10; i++) {
      svc.handleArkanoidEvent(const PowerUpCollected(PowerUpType.fast));
    }
    expect(svc.isUnlocked('bonus10'), isTrue);
    svc.handleArkanoidEvent(const ScoreChanged(999));
    expect(svc.isUnlocked('score1000'), isFalse);
    svc.handleArkanoidEvent(const ScoreChanged(1000));
    expect(svc.isUnlocked('score1000'), isTrue);
    svc.handleArkanoidEvent(const LevelCleared(3, false));
    expect(svc.isUnlocked('level3'), isTrue);
    svc.handleFuseballScore(24);
    expect(svc.isUnlocked('fuse25'), isFalse);
    svc.handleFuseballScore(25);
    expect(svc.isUnlocked('fuse25'), isTrue);
  });

  test('прогресс и достижения сохраняются между запусками', () {
    final storage = MemoryStorage();
    final first = make(storage);
    for (var i = 0; i < 40; i++) {
      first.handleArkanoidEvent(const BrickDestroyed(BrickType.normal));
    }
    first.handleArkanoidEvent(const BallCountChanged(3));

    final second = make(storage); // «новый запуск»
    expect(second.isUnlocked('triple'), isTrue);
    expect(second.progress(achievementList.first), closeTo(0.4, 1e-9));
  });

  test('рекорды: сохраняются и обновляются только при улучшении', () {
    final storage = MemoryStorage();
    final repo = GameRepository(storage);
    expect(repo.submitArkanoidScore(100), isTrue);
    expect(repo.submitArkanoidScore(50), isFalse);
    expect(repo.submitArkanoidScore(100), isFalse);
    expect(repo.submitFuseballScore(7), isTrue);
    final again = GameRepository(storage);
    expect(again.arkanoidRecord, 100);
    expect(again.fuseballRecord, 7);
  });

  test('повреждённое хранилище не ломает загрузку', () {
    final storage = MemoryStorage();
    storage.writeInt('record_arkanoid', -5);
    final repo = GameRepository(storage);
    expect(repo.submitArkanoidScore(10), isTrue);
  });
}
