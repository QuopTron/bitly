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

  // ── Modo claro: neutro / profundo ──
  static const verdeProfundo = Color(0xFF1A1A1A);
  static const verdeMedio = Color(0xFF333333);

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

  /// Base REAL que queda debajo de las letras de una card con cover.
  ///
  /// No es la superficie del tema: estas cards pintan su carátula con un velo
  /// oscuro y un degradado inferior de legibilidad que existen en los DOS
  /// temas, así que el fondo donde cae el texto es oscuro también en tema
  /// claro (por eso su texto de fábrica es blanco). Es el color que hay que
  /// pasarle a `EstiloHelper.textoDeTinte` para decidir las letras: con la
  /// superficie del tema (blanca en tema claro) el cálculo daba un fondo claro
  /// que no existe y las letras pasaban a negro sobre ese velo oscuro.
  static Color baseBajoCover(bool oscuro) {
    final conVelo = Color.alphaBlend(
      sombra(oscuro).withValues(alpha: 0.4),
      superficie(oscuro),
    );
    // El degradado inferior, que es donde se apoyan el título y el subtítulo.
    return Color.alphaBlend(Colors.black.withValues(alpha: 0.45), conVelo);
  }

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

  /// Superficie dinámica: aplica un tinte sutil del color dominante.
  static Color superficieDinamica(bool oscuro, Color? acento) {
    if (acento == null) return superficie(oscuro);
    return Color.lerp(superficie(oscuro), acento, oscuro ? 0.12 : 0.08)!;
  }

  /// Velo dinámico: mezcla el velo del tema con el color dominante.
  ///
  /// [base] reemplaza el velo del tema. Lo usan las cards que dejan de tener
  /// letras blancas: el velo existe para que el texto se lea sobre la portada,
  /// así que tiene que ser del color OPUESTO a las letras — una card clara con
  /// letras oscuras necesita un velo blanco, no negro.
  static Color veloDinamico(
    bool oscuro,
    Color? acento, {
    double alpha = 1.0,
    Color? base,
  }) {
    final neutro = base ?? velo(oscuro);
    if (acento == null) return neutro.withValues(alpha: alpha);
    final mix = Color.lerp(neutro, acento, 0.35)!;
    return mix.withValues(alpha: alpha);
  }

  /// Borde dinámico: si hay acento, usa un tinte del color dominante.
  static Color bordeDinamico(bool oscuro, Color? acento) {
    if (acento == null) return borde(oscuro);
    return acento.withValues(alpha: oscuro ? 0.25 : 0.18);
  }

  /// Sombra dinámica: si hay acento, tiñe la sombra con el color dominante.
  ///
  /// [base] reemplaza la sombra del tema, igual que en [veloDinamico]: la
  /// usan los degradados de legibilidad de las cards cuando las letras pasaron
  /// a oscuras (una sombra negra debajo de un texto negro lo tapa).
  static Color sombraDinamica(bool oscuro, Color? acento, {Color? base}) {
    final neutro = base ?? sombra(oscuro);
    if (acento == null) return neutro;
    return Color.lerp(neutro, acento, 0.3)!;
  }

  // ── Estados ──
  static const error = Color(0xFFE53935);
  static const exito = Color(0xFF4CAF50);
  static const advertencia = Color(0xFFFF9800);
}
