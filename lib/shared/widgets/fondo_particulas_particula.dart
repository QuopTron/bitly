// ─────────────────────────────────────────────────────────────
// fondo_particulas_particula.dart — PART de fondo_particulas.dart:
// modelo de una partícula flotante (posición, velocidad, opacidad,
// rotación, glifo de nota musical) con caché perezosa de su glow
// radial (pintura) y su glifo (TextPainter), para no relayoutear
// en cada frame. El glow/glyph se reconstruye solo cuando la
// apariencia cambia.
// Se conecta con: fondo_particulas.dart (misma library).
// Parte del flujo: presentación (fondo animado del splash/player).
// ─────────────────────────────────────────────────────────────

part of 'fondo_particulas.dart';

/// Partícula flotante con glow y glifo de nota musical cacheados.
class _Particula {
  double x, y, size, speedX, speedY, opacity, rotation, rotationSpeed;
  final String iconLabel;

  /// Glow radial cacheado (sin blur MaskFilter por frame). Se reconstruye
  /// solo cuando la partícula se crea o reinicia (cambia la opacidad).
  ui.Paint? glowPaint;

  /// Glifo cacheado (el layout de TextPainter es caro — nunca por frame).
  TextPainter? glyph;
  double _glyphAlpha = -1;
  Color _glyphColor = const Color(0x00000000);
  double _glyphSize = -1;

  _Particula({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
    required this.rotation,
    required this.rotationSpeed,
    required this.iconLabel,
  });

  /// Construye (o reconstruye si está obsoleto) el glow + glifo cacheados.
  /// Es barato llamarlo cada frame; no hace nada salvo que la apariencia
  /// realmente haya cambiado.
  void asegurarCache(Color glowColor, Color particleColor) {
    if (glowPaint == null) {
      final c = glowColor.withValues(alpha: opacity * 0.45);
      glowPaint = ui.Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          size * 1.6,
          [c, c.withValues(alpha: 0.0)],
        );
    }
    if (glyph == null ||
        _glyphAlpha != opacity ||
        _glyphColor != particleColor ||
        _glyphSize != size) {
      _glyphAlpha = opacity;
      _glyphColor = particleColor;
      _glyphSize = size;
      glyph = TextPainter(
        text: TextSpan(
          text: iconLabel,
          style: TextStyle(
            fontSize: size,
            height: 1,
            color: particleColor.withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
  }
}