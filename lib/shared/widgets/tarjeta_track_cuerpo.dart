// ─────────────────────────────────────────────────────────────
// tarjeta_track_cuerpo.dart — PART de tarjeta_track.dart: cuerpo
// de la tarjeta de track — contenedor con portada de fondo + velo,
// insignia de "listo", gradiente inferior, ripple y la fila con
// miniatura + título/artista + cluster de acciones. Recibe la
// tarjeta y los colores calculados para no duplicar lógica.
// Se conecta con: tarjeta_track.dart (misma library) + imagen_portada.
// Parte del flujo: búsqueda, feed, mi espacio (listas de tracks).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_track.dart';

/// Cuerpo completo de la tarjeta de track.
Widget _cuerpoTarjetaTrack(
  TarjetaTrack t,
  BuildContext context,
  Responsive r,
  AppLocalizations loc,
  bool esOscuro,
  Color fg,
  Color colorApagado,
  Color fondoFallback,
  Color colorIconoFallback,
  double tamanoIcono,
  double ts,
  bool efectosPesados,
) {
  return RepaintBoundary(
    child: Container(
      width: r.width * 0.82,
      margin: EdgeInsets.symmetric(
        horizontal: r.spacingS,
        vertical: r.spacingXS,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: t.estadoDescarga == EstadoDescarga.completado
              ? fg.withValues(alpha: 0.2)
              : fg.withValues(alpha: 0.1),
          width: t.estadoDescarga == EstadoDescarga.completado ? 1.0 : 0.7,
        ),
        boxShadow: [
          if (efectosPesados)
            BoxShadow(
              color: ColoresApp.sombra(esOscuro).withValues(
                  alpha: t.estadoDescarga == EstadoDescarga.completado
                      ? 0.35
                      : 0.3),
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Portada de fondo: decode a baja resolución — detrás del velo.
          if (t.coverUrl != null && t.coverUrl!.isNotEmpty)
            Positioned.fill(
              child: imagenDesdeUrl(
                t.coverUrl,
                ajuste: BoxFit.cover,
                ancho: 128,
                alto: 128,
              ),
            ),
          Positioned.fill(
            child: Container(
              color: ColoresApp.sombra(esOscuro).withValues(alpha: 0.4),
            ),
          ),
          if (t.readyKey != null && t.readyKey!.isNotEmpty)
            _insigniaListoDe(t, context, r, loc, fg, esOscuro),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    fg.withValues(alpha: esOscuro ? 0.05 : 0.0),
                    Colors.transparent,
                    ColoresApp.sombra(esOscuro)
                        .withValues(alpha: efectosPesados ? 0.45 : 0.3),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),
          // Ripple + feedback de tap: sobre el arte pero debajo del contenido
          // para que los botones de acción sigan recibiendo sus propios taps.
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: t.onTap,
                customBorder: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                splashColor: fg.withValues(alpha: 0.14),
                highlightColor: fg.withValues(alpha: 0.06),
              ),
            ),
          ),
          _filaContenidoTrack(
            t,
            context,
            r,
            loc,
            fg,
            colorApagado,
            fondoFallback,
            colorIconoFallback,
            tamanoIcono,
            ts,
            esOscuro,
            efectosPesados,
          ),
        ],
      ),
    ),
  );
}