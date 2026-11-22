import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/game_repository.dart';
import '../domain/achievements.dart';

/// Глобальное состояние приложения: рекорды и достижения.
/// Экраны подписываются на него через [AppScope].
class AppState extends ChangeNotifier {
  AppState(this.repo) : achievements = AchievementService(repo);

  final GameRepository repo;
  final AchievementService achievements;

  int get arkanoidRecord => repo.arkanoidRecord;
  int get fuseballRecord => repo.fuseballRecord;

  /// Возвращает true, если счёт стал новым рекордом.
  bool submitArkanoidScore(int score) {
    final isRecord = repo.submitArkanoidScore(score);
    if (isRecord) _notifyLater();
    return isRecord;
  }

  bool submitFuseballScore(int score) {
    final isRecord = repo.submitFuseballScore(score);
    if (isRecord) _notifyLater();
    return isRecord;
  }

  /// Уведомление откладывается, чтобы его можно было вызывать
  /// из dispose() и кадровых колбэков без конфликта со сборкой дерева.
  void _notifyLater() => scheduleMicrotask(notifyListeners);

  void refresh() => _notifyLater();
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  /// Подписывается на изменения (для build).
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Без подписки (для initState и обработчиков).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
