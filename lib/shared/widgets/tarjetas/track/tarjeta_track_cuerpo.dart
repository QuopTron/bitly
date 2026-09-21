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
  double nivel = 0,
}) {
  // Color dominante: viene del padre que ya verificó el estilo y preferencias.
  final acento = colorDominante;
  // Borde y sombra se cruzan 1:1 con la intensidad (antes cambiaban de golpe
  // al primer punto del control), igual que el fondo.
  final v = nivel;
  final bordeNormal = fg.withValues(alpha: 0.1);
  final sombraNormal = ColoresApp.sombra(esOscuro);

  return RepaintBoundary(
    child: Container(
      // La tarjeta define su propio margen lateral (única fuente del gap
      // horizontal): el host solo agrega padding vertical. Sin ancho fijo
      // — así se adapta a cualquier DPI/ancho sin dejar gaps falsos.
      //
      // Separación personalizable (Ajustes → Apariencia → Diseño): el eje X
      // mueve el hueco entre cards Y el margen contra los bordes; el eje Y el
      // hueco entre filas. Con el multiplicador de fábrica (1) queda igual.
      margin: EdgeInsets.symmetric(
        horizontal: r.spacingS * AparienciaEspacios.espacioXCancion(context),
        vertical: r.spacingXS * AparienciaEspacios.espacioYCancion(context),
      ),
      decoration: BoxDecoration(
        // Redondeo personalizable (Ajustes → Apariencia → Diseño): con el
        // valor de fábrica del control quedan los 18 px de siempre y con 0 la
        // card queda cuadrada.
        borderRadius: BorderRadius.circular(_radioCardTrack(context)),
        border: Border.all(
          color:
              t.estadoDescarga == EstadoDescarga.completado
                  ? fg.withValues(alpha: 0.2)
                  : acento == null
                  ? bordeNormal
                  : EstiloHelper.mezclarColor(
                    bordeNormal,
                    ColoresApp.bordeDinamico(esOscuro, acento),
                    v,
                  ),
          width: t.estadoDescarga == EstadoDescarga.completado ? 1.0 : 0.7,
        ),
        boxShadow: [
          if (efectosPesados)
            BoxShadow(
              color: (acento == null
                      ? sombraNormal
                      : EstiloHelper.mezclarColor(
                        sombraNormal,
                        ColoresApp.sombraDinamica(esOscuro, acento),
                        v,
                      ))
                  .withValues(
                    alpha:
                        t.estadoDescarga == EstadoDescarga.completado
                            ? 0.35
                            : 0.3,
                  ),
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
        ],
        // Detrás de la carátula: sólo el piso de la card. Se tiñe con el
        // nivel para que el borde y el fondo no vayan a distinto ritmo.
        color:
            acento == null
                ? null
                : EstiloHelper.mezclarColor(
                  ColoresApp.superficie(esOscuro),
                  ColoresApp.superficieDinamica(esOscuro, acento),
                  v,
                ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Capas de fondo: arte + tinte por intensidad + velo + gradientes
          // (tarjeta_track_fondo).
          ..._capasFondoTrack(t, fg, esOscuro, acento, nivel, efectosPesados),
          if (t.readyKey != null && t.readyKey!.isNotEmpty)
            _insigniaListoDe(t, context, r, loc, fg, esOscuro),
          // Ripple + feedback de tap: sobre el arte pero debajo del contenido
          // para que los botones de acción sigan recibiendo sus propios taps.
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: t.onTap,
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(_radioCardTrack(context)),
                  ),
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
