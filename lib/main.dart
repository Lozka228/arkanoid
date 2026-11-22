import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/game_repository.dart';
import 'data/game_storage.dart';
import 'presentation/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GameStorage storage;
  try {
    storage = SharedPrefsStorage(await SharedPreferences.getInstance());
  } catch (_) {
    // если хранилище недоступно — игра работает, но без сохранения
    storage = MemoryStorage();
  }
  runApp(ArkanoidApp(state: AppState(GameRepository(storage))));
}
