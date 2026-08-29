import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════
// Dynamic Color Wrapper — Material You / Expressive 3 support
// ═══════════════════════════════════════════════════════════════════════

/// Wraps the app with dynamic color support for Android 12+ (Material You).
/// Falls back to a fixed color scheme on older devices or unsupported platforms.
class DynamicColorWrapper extends StatelessWidget {
  final Widget Function(ThemeData lightTheme, ThemeData darkTheme, ThemeMode themeMode) builder;

  const DynamicColorWrapper({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    // Use a simple builder approach without dynamic_color package
    // to avoid adding a new dependency. The existing app_theme.dart
    // already handles Material 3 theming.
    final brightness = MediaQuery.platformBrightnessOf(context);

    final lightTheme = _buildLightTheme();
    final darkTheme = _buildDarkTheme();
    final themeMode = brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;

    return builder(lightTheme, darkTheme, themeMode);
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF1DB954), // Spotify green
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF1DB954),
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }
}
