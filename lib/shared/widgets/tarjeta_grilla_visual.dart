// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_visual.dart — PART de tarjeta_grilla.dart:
// helpers visuales — fondo borroso (o gradiente preset), portada
// nítida (circular para artistas) con badge, gradiente/icono
// placeholder y portada "gradient:N". Reciben la tarjeta.
// Se conecta con: tarjeta_grilla.dart (misma library) +
// imagen_portada + colores_app.
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

Widget _fondoTarjeta(
  TarjetaGrilla t,
  BuildContext context,
  bool efectosPesados,
  bool esOscuro,
) {
  if (t.coverUrl != null && t.coverUrl!.startsWith('gradient:')) {
    return _portadaGradienteDe(t, t.coverUrl!, 128);
  }
  if (t.coverUrl != null && t.coverUrl!.isNotEmpty) {
    if (efectosPesados) {
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: imagenDesdeUrl(
          t.coverUrl,
          ajuste: BoxFit.cover,
          ancho: 128,
          alto: 128,
        ),
      );
    }
    return Container(color: ColoresApp.superficie(esOscuro));
  }
  return Container(
    decoration: BoxDecoration(gradient: _gradientePlaceholderDe(context)),
  );
}

Widget _portadaNitidaDe(
  TarjetaGrilla t,
  BuildContext context,
  double lado,
  bool esOscuro,
  bool efectosPesados,
) {
  return Container(
    width: lado,
    height: lado,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      shape: t._esArtista ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: t._esArtista ? null : BorderRadius.circular(14),
      color: t.coverUrl == null ? ColoresApp.superficie(esOscuro) : null,
      border: Border.all(color: ColoresApp.borde(esOscuro), width: 0.6),
      boxShadow: efectosPesados
          ? [BoxShadow(
              color: ColoresApp.sombra(esOscuro).withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )]
          : null,
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (t.coverUrl != null && t.coverUrl!.startsWith('gradient:'))
          _portadaGradienteDe(t, t.coverUrl!, lado)
        else if (t.coverUrl != null && t.coverUrl!.isNotEmpty)
          imagenDesdeUrl(
            t.coverUrl,
            ajuste: BoxFit.cover,
            fallback: _iconoPlaceholderDe(t, lado, context),
          )
        else
          _iconoPlaceholderDe(t, lado, context),
        // El estado de descarga se muestra en la fila de acciones — sin
        // punto redundante sobre la portada.
        if (t.insigniaEsquina != null)
          Positioned(top: 6, left: 6, child: t.insigniaEsquina!),
      ],
    ),
  );
}

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