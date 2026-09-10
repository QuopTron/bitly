// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_info.dart — PART de tarjeta_grilla.dart: bloque
// de info + fila de acciones de la tarjeta de grilla — like con
// animación, descarga según estado, acción "más" y contador de
// reproducciones. Reciben la tarjeta (tipo, esAmado, callbacks).
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
) {
  // Info sobre velo oscuro en ambos temas → el neutro legible es blanco.
  final colorTexto = Colors.white;
  final colorApagado = Colors.white.withValues(alpha: 0.72);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      if (t.mostrarAcciones) _filaAccionesDe(t, context, r),
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
            Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
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
          shadows: [
            Shadow(color: ColoresApp.sombra(esOscuro), blurRadius: 4),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      if (t.contadorReproducciones > 0) ...[
        SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${t.contadorReproducciones} '
            '${AppLocalizations.of(context).setup.reproductions}',
            style: TextStyle(
              fontSize: r.footerSize - 3,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    ],
  );
}

Widget _filaAccionesDe(TarjetaGrilla t, BuildContext context, Responsive r) {
  final loc = AppLocalizations.of(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  // Los iconos van sobre el mismo velo oscuro que el texto → colores blancos.
  final fg = Colors.white;
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
          },            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                t.esAmado ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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
                child: Icon(_iconoDescargaDe(t), size: tamanoIcono,
                    color: _colorIconoDescargaDe(t, esOscuro)),
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