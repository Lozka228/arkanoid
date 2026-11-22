import 'dart:async';

import 'game_storage.dart';

/// Репозиторий: рекорды, счётчики достижений и список открытых достижений.
/// Данные кешируются в памяти, запись в хранилище идёт сразу (без ожидания).
class GameRepository {
  GameRepository(this._storage) {
    arkanoidRecord = _storage.readInt(_kArkanoid);
    fuseballRecord = _storage.readInt(_kFuseball);
    _unlocked = _storage.readList(_kUnlocked).toSet();
  }

  static const _kArkanoid = 'record_arkanoid';
  static const _kFuseball = 'record_fuseball';
  static const _kUnlocked = 'unlocked';

  final GameStorage _storage;
  late int arkanoidRecord;
  late int fuseballRecord;
  late Set<String> _unlocked;
  final Map<String, int> _counters = {};

  /// Возвращает true, если установлен новый рекорд.
  bool submitArkanoidScore(int score) {
    if (score <= arkanoidRecord) return false;
    arkanoidRecord = score;
    unawaited(_storage.writeInt(_kArkanoid, score));
    return true;
  }

  bool submitFuseballScore(int score) {
    if (score <= fuseballRecord) return false;
    fuseballRecord = score;
    unawaited(_storage.writeInt(_kFuseball, score));
    return true;
  }

  int counter(String key) =>
      _counters.putIfAbsent(key, () => _storage.readInt('cnt_$key'));

  void addCounter(String key, int delta) {
    final v = counter(key) + delta;
    _counters[key] = v;
    unawaited(_storage.writeInt('cnt_$key', v));
  }

  bool isUnlocked(String id) => _unlocked.contains(id);

  void unlock(String id) {
    if (_unlocked.add(id)) {
      unawaited(_storage.writeList(_kUnlocked, _unlocked.toList()));
    }
  }
}
