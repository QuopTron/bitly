// ─────────────────────────────────────────────────────────────
// paleta_portada_contraste.dart — PART de paleta_portada.dart:
// helpers de contraste WCAG — luminancia relativa, relación de
// contraste, ajuste de color para garantizar un ratio mínimo y el
// neutro más legible (blanco/negro) sobre un fondo dado.
// Se conecta con: paleta_portada.dart (misma library).
// Parte del flujo: reproductor (letras karaoke, contraste).
// ─────────────────────────────────────────────────────────────

part of 'paleta_portada.dart';

/// Luminancia relativa WCAG 2.x (0 = negro, 1 = blanco).
double luminanciaRelativa(Color c) {
  double canal(double v) {
    v = v / 255.0;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

/// Relación de contraste WCAG entre dos colores (1..21).
double relacionContraste(Color a, Color b) {
  final la = luminanciaRelativa(a);
  final lb = luminanciaRelativa(b);
  final claro = math.max(la, lb);
  final oscuro = math.min(la, lb);
  return (claro + 0.05) / (oscuro + 0.05);
}

/// Ajusta [color] (claro/oscuro) para mantener al menos [ratioMin]:1 de
/// contraste contra [fondo], preservando tono y saturación.
Color garantizarContraste(Color color, Color fondo, {double ratioMin = 4.0}) {
  if (relacionContraste(color, fondo) >= ratioMin) return color;
  final lumFondo = luminanciaRelativa(fondo);
  final hsl = HSLColor.fromColor(color);
  final irClaro = lumFondo < 0.5; // panel oscuro → texto claro
  var claridad = hsl.lightness;
  for (var i = 0; i < 24; i++) {
    claridad = irClaro
        ? math.min(1.0, claridad + 0.045)
        : math.max(0.0, claridad - 0.045);
    final candidato = hsl.withLightness(claridad).toColor();
    if (relacionContraste(candidato, fondo) >= ratioMin) return candidato;
  }
  // Último recurso: blanco puro sobre oscuro / negro puro sobre claro.
  return irClaro ? Colors.white : Colors.black;
}

/// Elige el neutro más legible (blanco o negro) sobre [fondo].
Color mejorNeutro(Color fondo) =>
    luminanciaRelativa(fondo) < 0.5 ? Colors.white : Colors.black;