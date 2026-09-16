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

Widget _fondoTarjeta(
  TarjetaGrilla t,
  BuildContext context,
  bool efectosPesados,
  bool esOscuro,
  Color? acento,
) {
  if (t.coverUrl != null && t.coverUrl!.startsWith('gradient:')) {
    return _portadaGradienteDe(t, t.coverUrl!, 128);
  }
  // En modo Spotify (acento != null), no mostramos cover borroso —
  // usamos el color dominante como fondo sólido de la card.
  if (acento != null) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(ColoresApp.superficie(esOscuro), acento, 0.40)!,
            Color.lerp(ColoresApp.superficie(esOscuro), acento, 0.18)!,
          ],
        ),
      ),
    );
  }
  // Modo Clásico: cover borroso o gradiente placeholder.
  if (t.coverUrl != null && t.coverUrl!.isNotEmpty) {
    if (efectosPesados) {
      return DesenfoqueHijo(
        sigma: 18,
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
