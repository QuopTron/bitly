// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_visual.dart — PART de tarjeta_grilla.dart:
// helpers visuales — portada nítida (circular para artistas) con
// badge, gradiente/icono placeholder y portada "gradient:N".
// El fondo completo vive en tarjeta_grilla_fondo.dart.
// Se conecta con: tarjeta_grilla.dart (misma library) +
// imagen_portada + colores_app.
// Parte del flujo: feed, búsqueda, mi espacio (tarjetas de grilla).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_grilla.dart';

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
      // Redondeo personalizable (Ajustes → Apariencia → Diseño); con el
      // valor de fábrica son los 14 px de siempre.
      borderRadius:
          t._esArtista
              ? null
              : BorderRadius.circular(AparienciaEspacios.radioCards(context)),
      color: t.coverUrl == null ? ColoresApp.superficie(esOscuro) : null,
      border: Border.all(color: ColoresApp.borde(esOscuro), width: 0.6),
      boxShadow:
          efectosPesados
              ? [
                BoxShadow(
                  color: ColoresApp.sombra(esOscuro).withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
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
