// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_placeholder.dart — PART de tarjeta_grilla.dart:
// arte de relleno cuando no hay portada — gradientes preset
// (coverUrl "gradient:N"), gradiente neutro del tema e icono
// circular según el tipo de tarjeta.
// Se conecta con: tarjeta_grilla.dart (misma library) + colores_app.
// Parte del flujo: feed, búsqueda, mi espacio (tarjetas de grilla).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_grilla.dart';

/// Gradientes preset para portadas sin arte (coverUrl "gradient:N").
const _gradientesPreset = [
  [Color(0xFF66A6FF), Color(0xFF00B4D8)],
  [Color(0xFF7B2FF7), Color(0xFFFF6B6B)],
  [Color(0xFFFFB347), Color(0xFFFF6B6B)],
  [Color(0xFF4ECDC4), Color(0xFF556270)],
];

LinearGradient _gradientePlaceholderDe(BuildContext context) {
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final c = ColoresApp.enSuperficie(esOscuro);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      c.withValues(alpha: 0.08),
      c.withValues(alpha: 0.02),
      ColoresApp.superficie(esOscuro),
    ],
    stops: const [0.0, 0.5, 1.0],
  );
}

Widget _iconoPlaceholderDe(TarjetaGrilla t, double tamano, BuildContext context) {
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final c = ColoresApp.enSuperficie(esOscuro);
  return Container(
    decoration: BoxDecoration(color: c.withValues(alpha: 0.05)),
    alignment: Alignment.center,
    child: Container(
      padding: EdgeInsets.all(tamano * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.15), width: 1.2),
      ),
      child: Icon(
        t._icono,
        size: tamano * 0.42,
        color: c.withValues(alpha: 0.9),
      ),
    ),
  );
}

Widget _portadaGradienteDe(TarjetaGrilla t, String coverUrl, double tamano) {
  final idx = int.tryParse(coverUrl.replaceFirst('gradient:', '')) ?? 0;
  final colores = idx >= 0 && idx < _gradientesPreset.length
      ? _gradientesPreset[idx]
      : _gradientesPreset[0];
  return Container(
    width: tamano,
    height: tamano,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: colores,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Icon(Icons.music_note_rounded,
          color: Colors.white.withValues(alpha: 0.7), size: tamano * 0.4),
    ),
  );
}
