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
  // `Color.r/g/b` YA vienen normalizados en 0..1 (Flutter ≥3.27), que es justo
  // lo que pide la fórmula. Antes se los volvía a dividir por 255 —correcto con
  // la API vieja de `Color.red` 0..255—, así que el blanco terminaba con una
  // luminancia de 0.0003: TODO par de colores daba un contraste de ~1 y las
  // reglas de contraste (las letras de las cards, el karaoke) no se cumplían.
  double canal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

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
    claridad =
        irClaro
            ? math.min(1.0, claridad + 0.045)
            : math.max(0.0, claridad - 0.045);
    final candidato = hsl.withLightness(claridad).toColor();
    if (relacionContraste(candidato, fondo) >= ratioMin) return candidato;
  }
  // Último recurso: blanco puro sobre oscuro / negro puro sobre claro.
  return irClaro ? Colors.white : Colors.black;
}

/// Acomoda [fondo] —oscureciéndolo o aclarándolo— hasta que [texto] llegue a
/// [ratioMin]:1 encima.
///
/// Es el caso inverso de [garantizarContraste]: ahí se mueve el TEXTO para que
/// se lea sobre un fondo fijo (el panel del karaoke). Acá el texto es el del
/// tema —en un fondo a pantalla completa hay decenas de letras y no se pueden
/// recolorear una por una— y lo que se mueve es el FONDO. Se recorre la
/// claridad de a poco para no cambiar el color más de lo necesario (y si ya se
/// leía, no se toca).
Color fondoParaTexto(Color fondo, Color texto, {double ratioMin = 4.5}) {
  if (relacionContraste(texto, fondo) >= ratioMin) return fondo;
  final hsl = HSLColor.fromColor(fondo);
  final textoClaro = luminanciaRelativa(texto) >= 0.5;
  var claridad = hsl.lightness;
  for (var i = 0; i < 30; i++) {
    claridad =
        textoClaro
            ? math.max(0.0, claridad - 0.03)
            : math.min(1.0, claridad + 0.03);
    final candidato = hsl.withLightness(claridad).toColor();
    if (relacionContraste(texto, candidato) >= ratioMin) return candidato;
  }
  // Último recurso: el neutro que contrasta con el texto.
  return textoClaro ? Colors.black : Colors.white;
}

/// Elige el neutro más legible (blanco o negro) sobre [fondo].
///
/// Se comparan las DOS relaciones de contraste reales en vez de mirar si el
/// fondo "parece" claro u oscuro: el punto donde blanco y negro empatan está en
/// una luminancia relativa de ~0.18 (no en 0.5, que es el medio de la escala
/// perceptual). Usar 0.5 devolvía BLANCO sobre un fondo con el 21% de
/// luminancia —un gris medio claro, justo el que dejan los covers blancos al
/// teñir— donde el blanco da 2.7:1 y el negro 7.8:1: la letra se perdía.
Color mejorNeutro(Color fondo) =>
    relacionContraste(Colors.white, fondo) >=
            relacionContraste(Colors.black, fondo)
        ? Colors.white
        : Colors.black;
