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
  bool efectosPesados, {
  Color? colorDominante,
}) {
  // Color dominante: viene del padre que ya verificó el estilo y preferencias.
  final acento = colorDominante;

  return RepaintBoundary(
    child: Container(
      // La tarjeta define su propio margen lateral (única fuente del gap
      // horizontal): el host solo agrega padding vertical. Sin ancho fijo
      // — así se adapta a cualquier DPI/ancho sin dejar gaps falsos.
      margin: EdgeInsets.symmetric(
        horizontal: r.spacingS,
        vertical: r.spacingXS,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: t.estadoDescarga == EstadoDescarga.completado
              ? fg.withValues(alpha: 0.2)
              : acento != null
                  ? ColoresApp.bordeDinamico(esOscuro, acento)
                  : fg.withValues(alpha: 0.1),
          width: t.estadoDescarga == EstadoDescarga.completado ? 1.0 : 0.7,
        ),
        boxShadow: [
          if (efectosPesados)
            BoxShadow(
              color: (acento != null
                      ? ColoresApp.sombraDinamica(esOscuro, acento)
                      : ColoresApp.sombra(esOscuro))
                  .withValues(
                      alpha: t.estadoDescarga == EstadoDescarga.completado
                          ? 0.35
                          : 0.3),
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
        ],
        color: acento != null
            ? ColoresApp.superficieDinamica(esOscuro, acento)
            : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Capas de fondo: arte + velo + gradientes (tarjeta_track_fondo).
          ..._capasFondoTrack(t, fg, esOscuro, acento, efectosPesados),
          if (t.readyKey != null && t.readyKey!.isNotEmpty)
            _insigniaListoDe(t, context, r, loc, fg, esOscuro),
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