import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1DB954);
  static const Color primaryDark = Color(0xFF1AA34A);
  static const Color primaryLight = Color(0xFF4BC97C);

  static const Color secondary = Color(0xFF169C7C);
  static const Color secondaryDark = Color(0xFF128A6D);
  static const Color secondaryLight = Color(0xFF4DBA9F);

  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF181818);
  static const Color surfaceHigh = Color(0xFF282828);

  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFFB3B3B3);
  static const Color onSurfaceVariant = Color(0xFF535353);

  static const Color error = Color(0xFFE22134);
  static const Color success = Color(0xFF1DB954);
  static const Color warning = Color(0xFFFFA42B);
  static const Color info = Color(0xFF2E77D0);

  static const Color glassBackground = Color(0x80121212);
  static const Color neonGlow = Color(0x401DB954);

  static const ColorScheme darkScheme = ColorScheme.dark(
    primary: primary,
    primaryContainer: primaryDark,
    secondary: secondary,
    secondaryContainer: secondaryDark,
    surface: surface,
    surfaceContainerHighest: surfaceHigh,
    onPrimary: onPrimary,
    onSecondary: onPrimary,
    onSurface: onSurface,
    error: error,
  );
}
