import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0B1020);
  static const surface = Color(0xFF141B34);
  static const field = Color(0xFF0E1530);
  static const accent = Color(0xFF22D3EE);
  static const accent2 = Color(0xFFF472B6);
  static const gold = Color(0xFFFFC857);
  static const silver = Color(0xFFB8C0CC);
  static const text = Color(0xFFF1F5F9);
  static const muted = Color(0xFF94A3B8);
  static const brickRows = <Color>[
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFF84CC16),
    Color(0xFF22C55E),
    Color(0xFF38BDF8),
    Color(0xFF818CF8),
    Color(0xFFC084FC),
    Color(0xFFF472B6),
  ];
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    surface: AppColors.surface,
    primary: AppColors.accent,
    onPrimary: const Color(0xFF00212B),
    secondary: AppColors.accent2,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
  );
  const buttonText = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: buttonText,
        side: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 48),
        textStyle: buttonText,
      ),
    ),
  );
}
