import 'package:shared_preferences/shared_preferences.dart';

/// Абстракция над локальным хранилищем (позволяет подменять его в тестах).
abstract class GameStorage {
  int readInt(String key);
  Future<void> writeInt(String key, int value);
  List<String> readList(String key);
  Future<void> writeList(String key, List<String> value);
}

class SharedPrefsStorage implements GameStorage {
  SharedPrefsStorage(this._prefs);
  final SharedPreferences _prefs;

  @override
  int readInt(String key) {
    try {
      return _prefs.getInt(key) ?? 0;
    } catch (_) {
      return 0; // повреждённое значение — считаем, что данных нет
    }
  }

  @override
  Future<void> writeInt(String key, int value) async {
    try {
      await _prefs.setInt(key, value);
    } catch (_) {}
  }

  @override
  List<String> readList(String key) {
    try {
      return _prefs.getStringList(key) ?? <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  @override
  Future<void> writeList(String key, List<String> value) async {
    try {
      await _prefs.setStringList(key, value);
    } catch (_) {}
  }
}

class MemoryStorage implements GameStorage {
  final Map<String, Object> _data = {};

  @override
  int readInt(String key) {
    final v = _data[key];
    return v is int ? v : 0;
  }

  @override
  Future<void> writeInt(String key, int value) async => _data[key] = value;

  @override
  List<String> readList(String key) {
    final v = _data[key];
    return v is List<String> ? List<String>.of(v) : <String>[];
  }

  @override
  Future<void> writeList(String key, List<String> value) async =>
      _data[key] = List<String>.of(value);
}
