// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_info.dart — PART de tarjeta_grilla.dart: bloque
// de info + fila de acciones de la tarjeta de grilla — like con
// animación, descarga según estado, acción "más" y contador de
// reproducciones. Reciben la tarjeta (tipo, esAmado, callbacks) y el
// color de letras ya adaptado al tinte (fg).
//
// El color no se fija acá: llega resuelto desde el `build`
// (`EstiloHelper.textoDeTinte` contra la base real de la card). Si el tinte
// dejó la card clara, las letras vienen oscuras —y el velo de la card se aclara
// junto con ellas (tarjeta_grilla_fondo)—, así que el bloque se lee siempre.
// Se conecta con: misma library + shared (indicador, colores,
// haptico, responsive, l10n).
// Parte del flujo: feed, búsqueda, mi espacio (tarjetas grilla).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_grilla.dart';

Widget _bloqueInfoDe(
  TarjetaGrilla t,
  BuildContext context,
  Responsive r,
  double ts,
  Color fg,
) {
  // El texto va sobre el velo de la card, y ese velo sigue a las letras.
  final colorTexto = fg;
  final colorApagado = fg.withValues(alpha: 0.72);
  // El halo del texto es el neutro que contrasta con él: con las letras
  // oscuras de una card clara, un halo negro las embarraría.
  final halo = mejorNeutro(colorTexto);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      if (t.mostrarAcciones) _filaAccionesDe(t, context, r, fg),
      SizedBox(height: r.spacingXS),
      Text(
        t.titulo,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: (r.footerSize + 5) * ts,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: colorTexto,
          shadows: [
            Shadow(color: halo.withValues(alpha: 0.3), blurRadius: 8),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      SizedBox(height: 2),
      Text(
        t.subtitulo,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: r.footerSize * ts,
          fontWeight: FontWeight.w400,
          color: colorApagado,
          shadows: [Shadow(color: halo.withValues(alpha: 0.25), blurRadius: 4)],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      if (t.contadorReproducciones > 0) ...[
        SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: fg.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${t.contadorReproducciones} '
            '${AppLocalizations.of(context).setup.reproductions}',
            // El chip es chico y la palabra viene de la traducción: recorta en
            // vez de envolverse y romper la línea de la grilla.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.footerSize - 3,
              color: fg.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    ],
  );
}

Widget _filaAccionesDe(
  TarjetaGrilla t,
  BuildContext context,
  Responsive r,
  Color fg,
) {
  final loc = AppLocalizations.of(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  // Los iconos van sobre el mismo velo que el texto y con su mismo color.
  final tamanoIcono = r.footerSize * 1.8;
  Widget fila = Wrap(
    alignment: WrapAlignment.center,
    spacing: r.spacingM * 0.6,
    runSpacing: 2,
    children: <Widget>[
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
            transitionBuilder:
                (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(
              t.esAmado
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              key: ValueKey(t.esAmado),
              color: t.esAmado ? ColoresApp.error : fg.withValues(alpha: 0.8),
              size: tamanoIcono,
            ),
          ),
        ),
      ),
      if (!t._esArtista && t.mostrarAccionDescarga)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IndicadorDescarga(
              estado: t.estadoDescarga,
              tamano: 10,
              progreso: t.progresoDescarga,
            ),
            SizedBox(width: 4),
            Tooltip(
              message: _tooltipDescarga(t, loc),
              child: GestureDetector(
                onTap: _accionDescargaDe(t),
                child: Icon(
                  _iconoDescargaDe(t),
                  size: tamanoIcono,
                  color: _colorIconoDescargaDe(t, esOscuro),
                ),
              ),
            ),
          ],
        ),
      if (t.mostrarTerceraAccion)
        Semantics(
          button: true,
          label: loc.setup.a11yMore,
          child: GestureDetector(
            onTap: t.onMas,
            child: Icon(
              Icons.more_horiz,
              size: tamanoIcono + 2,
              color: fg.withValues(alpha: 0.6),
            ),
          ),
        ),
    ],
  );

  if (t.accionesHabilitadas) return fila;
  return IgnorePointer(child: Opacity(opacity: 0.4, child: fila));
}
