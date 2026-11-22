import 'package:flutter/material.dart';

import '../data/game_repository.dart';
import 'models.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.goal = 1,
    this.counter,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Целевое значение счётчика (для накопительных достижений).
  final int goal;

  /// Ключ накопительного счётчика (null — достижение разовое).
  final String? counter;
}

const String kCounterBricks = 'bricks';
const String kCounterArmored = 'armored';
const String kCounterBonuses = 'bonuses';

const List<Achievement> achievementList = [
  Achievement(
    id: 'bricks100',
    title: 'Разрушитель',
    description: 'Разбить 100 блоков',
    icon: Icons.grid_view_rounded,
    goal: 100,
    counter: kCounterBricks,
  ),
  Achievement(
    id: 'flawless',
    title: 'Без единой царапины',
    description: 'Пройти уровень без потери жизней',
    icon: Icons.favorite_rounded,
  ),
  Achievement(
    id: 'triple',
    title: 'Тройной удар',
    description: 'Поймать 3 мяча одновременно (бонус «Три мяча»)',
    icon: Icons.bubble_chart,
  ),
  Achievement(
    id: 'armor25',
    title: 'Бронебойный',
    description: 'Разбить 25 бронированных блоков',
    icon: Icons.shield_rounded,
    goal: 25,
    counter: kCounterArmored,
  ),
  Achievement(
    id: 'bonus10',
    title: 'Коллекционер бонусов',
    description: 'Поймать 10 бонусов',
    icon: Icons.card_giftcard_rounded,
    goal: 10,
    counter: kCounterBonuses,
  ),
  Achievement(
    id: 'score1000',
    title: 'Тысячник',
    description: 'Набрать 1000 очков за одну игру в Арканоид',
    icon: Icons.emoji_events_rounded,
  ),
  Achievement(
    id: 'level3',
    title: 'Покоритель уровней',
    description: 'Пройти 3 уровня в одной игре',
    icon: Icons.flag_rounded,
  ),
  Achievement(
    id: 'fuse25',
    title: 'Мастер Fuseball',
    description: 'Набрать 25 очков в Fuseball',
    icon: Icons.sports_soccer_rounded,
  ),
];

int get achievementTotal => achievementList.length;

class AchievementService {
  AchievementService(this._repo);

  final GameRepository _repo;

  /// Вызывается при открытии нового достижения (экран показывает уведомление).
  void Function(Achievement achievement)? onUnlocked;

  bool isUnlocked(String id) => _repo.isUnlocked(id);

  int get unlockedCount => achievementList.where((a) => isUnlocked(a.id)).length;

  /// Прогресс от 0.0 до 1.0.
  double progress(Achievement a) {
    if (isUnlocked(a.id)) return 1;
    final key = a.counter;
    if (key == null) return 0;
    return (_repo.counter(key) / a.goal).clamp(0.0, 1.0).toDouble();
  }

  int currentValue(Achievement a) {
    final key = a.counter;
    if (key == null) return isUnlocked(a.id) ? 1 : 0;
    return _repo.counter(key).clamp(0, a.goal).toInt();
  }

  void handleArkanoidEvent(GameEvent event) {
    switch (event) {
      case BrickDestroyed(:final type):
        _repo.addCounter(kCounterBricks, 1);
        if (type != BrickType.normal) {
          _repo.addCounter(kCounterArmored, 1);
        }
        _checkCounters();
      case PowerUpCollected():
        _repo.addCounter(kCounterBonuses, 1);
        _checkCounters();
      case BallCountChanged(:final count):
        if (count >= 3) _unlock('triple');
      case LevelCleared(:final level, :final flawless):
        if (flawless) _unlock('flawless');
        if (level >= 3) _unlock('level3');
      case ScoreChanged(:final score):
        if (score >= 1000) _unlock('score1000');
      case LifeLost() || GameOver():
        break;
    }
  }

  void handleFuseballScore(int score) {
    if (score >= 25) _unlock('fuse25');
  }

  void _checkCounters() {
    for (final a in achievementList) {
      final key = a.counter;
      if (key != null && _repo.counter(key) >= a.goal) _unlock(a.id);
    }
  }

  void _unlock(String id) {
    if (_repo.isUnlocked(id)) return;
    _repo.unlock(id);
    final a = achievementList.firstWhere((x) => x.id == id);
    onUnlocked?.call(a);
  }
}
