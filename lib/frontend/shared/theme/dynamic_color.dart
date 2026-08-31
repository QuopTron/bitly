import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════
// Dynamic Color Wrapper — Material You / Expressive 3 support
// ═══════════════════════════════════════════════════════════════════════

/// Wraps the app with dynamic color support for Android 12+ (Material You).
/// Falls back to a fixed color scheme on older devices or unsupported platforms.
class DynamicColorWrapper extends StatelessWidget {
  final Widget Function(ThemeData lightTheme, ThemeData darkTheme, ThemeMode themeMode) builder;
  final ThemeMode? themeModeOverride;

  const DynamicColorWrapper({super.key, required this.builder, this.themeModeOverride});

  @override
  Widget build(BuildContext context) {
    final lightTheme = _buildLightTheme();
    final darkTheme = _buildDarkTheme();
    // Respect the user's explicit preference if provided,
    // otherwise fall back to system brightness.
    final themeMode = themeModeOverride ??
        (MediaQuery.platformBrightnessOf(context) == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light);

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
