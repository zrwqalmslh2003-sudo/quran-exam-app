import 'package:flutter/material.dart';

const modernBg = Color(0xFF081126);
const modernSurface = Color(0xFF141E3B);
const modernSurface2 = Color(0xFF1B274A);
const modernPurple = Color(0xFF7B4DFF);
const modernBlue = Color(0xFF2D86FF);

ThemeData buildModernTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: modernPurple,
    brightness: Brightness.dark,
  ).copyWith(
    primary: modernPurple,
    onPrimary: Colors.white,
    secondary: modernBlue,
    onSecondary: Colors.white,
    surface: modernSurface,
    onSurface: Colors.white,
    surfaceContainerHighest: modernSurface2,
    outline: const Color(0xFF66718E),
    outlineVariant: const Color(0xFF38466E),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: modernBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: modernPurple,
    ),
  );
}
