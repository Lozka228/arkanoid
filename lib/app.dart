import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'presentation/app_state.dart';
import 'presentation/screens/home_screen.dart';

class ArkanoidApp extends StatelessWidget {
  const ArkanoidApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Арканоид',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
