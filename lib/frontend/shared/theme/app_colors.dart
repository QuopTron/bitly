import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand core (both modes) ──
  static const primary = Color(0xFFFFFFFF);

  // Legacy alias used by the splash glow circle; neutral to match the
  // monochrome brand (was the old green accent).
  static const darkGreen = Color(0xFFE0E0E0);

  // ── Dark mode: neutral / bright ──
  static const greenBright = Color(0xFFFFFFFF);
  static const greenNeon = Color(0xFFE0E0E0);
  static const greenPale = Color(0xFFB0B0B0);

  // ── Light mode: neutral / deep ──
  static const greenDeep = Color(0xFF1A1A1A);
  static const greenMedium = Color(0xFF333333);
  static const greenLight = Color(0xFF666666);

  // ── Backgrounds ──
  static const bgDark = Color(0xFF000000);
  static const bgLight = Color(0xFFFFFFFF);

  // ── Surface / Sheet backgrounds (dark / light pair) ──
  static const surfaceDark = Color(0xFF1A1A1A);
  static const surfaceLight = Color(0xFFF5F5F5);

  // ── Theme-aware getters ──
  // Use these instead of hardcoded Colors.white/Colors.black

  /// Primary text color (white on dark, black on light)
  static Color onSurface(bool isDark) => isDark ? Colors.white : Colors.black;

  /// Muted/secondary text color
  static Color onSurfaceMuted(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5);

  /// Very muted text color
  static Color onSurfaceFaint(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3);

  /// Surface background for cards/sheets
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;

  /// Page background
  static Color background(bool isDark) => isDark ? bgDark : bgLight;

  /// Border color
  static Color border(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);

  /// Subtle border color
  static Color borderSubtle(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);

  /// Splash/ripple color
  static Color splash(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.06);

  /// Shadow color
  static Color shadow(bool isDark) =>
      isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.15);

  /// Overlay/scrim color
  static Color scrim(bool isDark) =>
      isDark ? Colors.black.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.5);

  /// Error/accent color (red)
  static const error = Color(0xFFE53935);

  /// Success/accent color (green)
  static const success = Color(0xFF4CAF50);

  /// Warning/accent color (orange)
  static const warning = Color(0xFFFF9800);
}

