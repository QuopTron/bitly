// ─────────────────────────────────────────────────────────────
// tarjeta_track_acciones.dart — PART de tarjeta_track.dart:
// insignia "listo" (stream pre-resuelto) + cluster de acciones
// (like animado, descarga, compartir, info, más). Reciben la
// tarjeta para sus callbacks. Se conecta con la misma library
// + reproductor (tracksListos) + indicador + colores + haptico.
// Parte del flujo: búsqueda, feed, mi espacio (listas de tracks).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_track.dart';

Widget _insigniaListoDe(
  TarjetaTrack t,
  BuildContext context,
  Responsive r,
  AppLocalizations loc,
  Color fg,
  bool esOscuro,
) {
  return Positioned(
    top: r.spacingXS,
    left: r.spacingS,
    child: ValueListenableBuilder<Set<String>>(
      valueListenable: sl<CubitReproductor>().tracksListos,
      builder: (context, listos, _) => listos.contains(t.readyKey)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ColoresApp.sombra(esOscuro).withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt,
                    size: r.footerSize - 2,
                    color: fg.withValues(alpha: 0.8),
                  ),
                  SizedBox(width: 3),
                  Text(
                    loc.setup.readyBadge,
                    style: TextStyle(
                      fontSize: r.footerSize - 3,
                      fontWeight: FontWeight.w700,
                      color: fg.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    ),
  );
}

Widget _clusterAccionesDe(
  TarjetaTrack t,
  BuildContext context,
  Responsive r,
  AppLocalizations loc,
  double tamanoIcono,
  Color colorApagado,
  Color fg,
  bool esOscuro,
) {
  Widget cluster = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IndicadorDescarga(
        estado: t.mostrarAnimacionBorrar
            ? EstadoDescarga.completado
            : t.estadoDescarga,
        tamano: 10,
      ),
      SizedBox(width: r.spacingS),
      Semantics(
        button: true,
        label: t.esAmado ? loc.setup.a11yUnlike : loc.setup.a11yLike,
        child: GestureDetector(
          onTap: () {
            Haptico.medio();
            t.onLike?.call();
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
          child: Icon(
            t.esAmado ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(t.esAmado),
            color: t.esAmado ? ColoresApp.error : fg.withValues(alpha: 0.6),
            size: tamanoIcono,
          ),
          ),
        ),
      ),
      SizedBox(width: r.spacingXS),
      Tooltip(
        message: _tooltipDescarga(t, loc),
        child: GestureDetector(
          onTap: _accionDescargaDe(t),
          child: Icon(_iconoDescargaDe(t), size: tamanoIcono,
              color: _colorIconoDescargaDe(t, esOscuro)),
        ),
      ),
      SizedBox(width: r.spacingXS),
      Semantics(
        button: true,
        label: loc.setup.a11yShare,
        child: GestureDetector(
          onTap: t.onCompartir,
          child: Icon(Icons.share, size: tamanoIcono, color: colorApagado),
        ),
      ),
      SizedBox(width: r.spacingXS),
      Semantics(
        button: true,
        label: loc.setup.a11yInfo,
        child: GestureDetector(
          onTap: t.onInfo,
          child: Icon(Icons.info_outline, size: tamanoIcono, color: colorApagado),
        ),
      ),
      SizedBox(width: r.spacingXS),
      Semantics(
        button: true,
        label: loc.setup.a11yMore,
        child: GestureDetector(
          onTap: t.onMas,
          child: Icon(Icons.more_horiz, size: tamanoIcono + 2,
              color: fg.withValues(alpha: 0.5)),
        ),
      ),
      if (t.onEditarEtiquetas != null) ...[
        SizedBox(width: r.spacingXS),
        Semantics(
          button: true,
          label: loc.setup.editTags,
          child: GestureDetector(
            onTap: t.onEditarEtiquetas,
            child: Icon(Icons.edit, size: tamanoIcono, color: colorApagado),
          ),
        ),
      ],
    ],
  );

  if (t.accionesHabilitadas) return cluster;
  return IgnorePointer(child: Opacity(opacity: 0.4, child: cluster));
}