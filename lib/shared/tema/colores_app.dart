// ─────────────────────────────────────────────────────────────
// colores_app.dart — Paleta de colores global de la app: marca
// monocromática (blanco/negro/neutros) + getters conscientes del
// tema (oscuro/claro) para textos, superficies, bordes, sombras y
// estados (error/success/warning). Centraliza los colores para que
// las vistas no dupliquen valores hardcodeados.
// Se conecta con: todas las vistas y widgets (theme-aware).
// Parte del flujo: presentación (tema global).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Paleta de colores global con getters según tema oscuro/claro.
class ColoresApp {
  ColoresApp._();

  // ── Marca core (ambos modos) ──
  static const primario = Color(0xFFFFFFFF);

  /// Alias legacy del glow del splash; neutro para la marca monocromática.
  static const verdeOscuro = Color(0xFFE0E0E0);

  // ── Modo oscuro: neutro / brillante ──
  static const verdeBrillante = Color(0xFFFFFFFF);
  static const verdeNeon = Color(0xFFE0E0E0);
  static const verdePalido = Color(0xFFB0B0B0);

  // ── Modo claro: neutro / profundo ──
  static const verdeProfundo = Color(0xFF1A1A1A);
  static const verdeMedio = Color(0xFF333333);
  static const verdeClaro = Color(0xFF666666);

  // ── Fondos ──
  static const fondoOscuro = Color(0xFF000000);
  static const fondoClaro = Color(0xFFFFFFFF);

  // ── Superficies / hojas (par oscuro/claro) ──
  static const superficieOscura = Color(0xFF1A1A1A);
  static const superficieClara = Color(0xFFF5F5F5);

  // ── Getters theme-aware (usar en vez de Colors.white/black fijos) ──

  /// Color de texto primario.
  static Color enSuperficie(bool oscuro) =>
      oscuro ? Colors.white : Colors.black;

  /// Color de texto secundario/apagado.
  static Color enSuperficieApagado(bool oscuro) =>
      oscuro
          ? Colors.white.withValues(alpha: 0.5)
          : Colors.black.withValues(alpha: 0.5);

  /// Color de texto muy apagado.
  static Color enSuperficieTenue(bool oscuro) =>
      oscuro
          ? Colors.white.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.3);

  /// Fondo de tarjetas/hojas.
  static Color superficie(bool oscuro) =>
      oscuro ? superficieOscura : superficieClara;

  /// Fondo de página.
  static Color fondo(bool oscuro) => oscuro ? fondoOscuro : fondoClaro;

  /// Color de borde.
  static Color borde(bool oscuro) =>
      oscuro
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.1);

  /// Color de borde sutil.
  static Color bordeSutil(bool oscuro) =>
      oscuro
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06);

  /// Color de splash/ripple.
  static Color splash(bool oscuro) =>
      oscuro
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.black.withValues(alpha: 0.06);

  /// Color de sombra.
  static Color sombra(bool oscuro) =>
      oscuro
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.15);

  /// Color de overlay/scrim.
  static Color velo(bool oscuro) =>
      oscuro
          ? Colors.black.withValues(alpha: 0.7)
          : Colors.black.withValues(alpha: 0.5);

  // ── Getters dinámicos (estilo Spotify) ──

  /// Fondo dinámico: si hay acento, usa un velo del color dominante;
  /// si no, retorna el fondo estático del tema.
  static Color fondoDinamico(bool oscuro, Color? acento) {
    if (acento == null) return fondo(oscuro);
    return Color.lerp(fondo(oscuro), acento, oscuro ? 0.18 : 0.12)!;
  }

  /// Superficie dinámica: aplica un tinte sutil del color dominante.
  static Color superficieDinamica(bool oscuro, Color? acento) {
    if (acento == null) return superficie(oscuro);
    return Color.lerp(superficie(oscuro), acento, oscuro ? 0.12 : 0.08)!;
  }

  /// Velo dinámico: mezcla el velo del tema con el color dominante.
  static Color veloDinamico(bool oscuro, Color? acento, {double alpha = 1.0}) {
    final base = velo(oscuro);
    if (acento == null) return base.withValues(alpha: alpha);
    final mix = Color.lerp(base, acento, 0.35)!;
    return mix.withValues(alpha: alpha);
  }

  /// Borde dinámico: si hay acento, usa un tinte del color dominante.
  static Color bordeDinamico(bool oscuro, Color? acento) {
    if (acento == null) return borde(oscuro);
    return acento.withValues(alpha: oscuro ? 0.25 : 0.18);
  }

  /// Sombra dinámica: si hay acento, tiñe la sombra con el color dominante.
  static Color sombraDinamica(bool oscuro, Color? acento) {
    if (acento == null) return sombra(oscuro);
    return Color.lerp(sombra(oscuro), acento, 0.3)!;
  }

  /// Gradiente de fondo para cards: usa el color dominante como base.
  static LinearGradient gradienteDinamico(bool oscuro, Color? acento,
      {double alphaBase = 1.0, double alphaTop = 0.2}) {
    final colorBase = acento ?? (oscuro ? superficieOscura : superficieClara);
    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        colorBase.withValues(alpha: alphaBase),
        colorBase.withValues(alpha: alphaTop),
      ],
    );
  }

  // ── Estados ──
  static const error = Color(0xFFE53935);
  static const exito = Color(0xFF4CAF50);
  static const advertencia = Color(0xFFFF9800);
}