// ─────────────────────────────────────────────────────────────
// envoltorio_color_dinamico.dart — Soporte de color dinámico
// (Material You / Expressive 3) para Android 12+: envuelve la app
// construyendo los temas claro/oscuro y respetando la preferencia
// del usuario o el brillo del sistema. Cae a un esquema fijo neutro
// en dispositivos antiguos o plataformas sin soporte.
// Se conecta con: app.dart (tema raíz de la app).
// Parte del flujo: presentación (tema global).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Envuelve la app con color dinámico (Android 12+) o esquema fijo neutro.
class EnvoltorioColorDinamico extends StatelessWidget {
  final Widget Function(
    ThemeData lightTheme,
    ThemeData darkTheme,
    ThemeMode themeMode,
  )
  builder;
  final ThemeMode? themeModeOverride;

  /// Familia tipográfica con la que se pinta TODA la app (Ajustes → Apariencia
  /// → Tipografía).
  ///
  /// Antes la app empaquetaba Google Sans Flex y nunca la aplicaba: el
  /// `ThemeData` no declaraba `fontFamily`, así que todo se dibujaba con la
  /// tipografía del sistema. Con esto la elección del usuario llega de verdad
  /// al tema. null = la del sistema (mientras la elegida se termina de bajar).
  final String? fontFamily;

  const EnvoltorioColorDinamico({
    super.key,
    required this.builder,
    this.themeModeOverride,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final lightTheme = _buildLightTheme();
    final darkTheme = _buildDarkTheme();
    // Respeta la preferencia explícita del usuario; si no, brillo del sistema.
    final themeMode =
        themeModeOverride ??
        (MediaQuery.platformBrightnessOf(context) == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light);

    return builder(lightTheme, darkTheme, themeMode);
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF333333), // Neutro
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      fontFamily: fontFamily,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFFE0E0E0), // Neutro
      scaffoldBackgroundColor: const Color(0xFF121212),
      fontFamily: fontFamily,
    );
  }
}
