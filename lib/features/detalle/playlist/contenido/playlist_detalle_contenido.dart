// ─────────────────────────────────────────────────────────────
// playlist_detalle_contenido.dart — PART de playlist_detalle_pagina.dart:
// children de la cabecera — barra de progreso del lote en curso,
// banner de solo-descargados sin red y la lista de tracks con
// like/descarga/borrar/reproducir/compartir y la carátula resuelta.
// Se conecta con: playlist_detalle_pagina.dart (misma library) +
// tarjeta_track + hoja_opciones_descarga + share_plus.
// Parte del flujo: Detalle → playlist (contenido).
// ─────────────────────────────────────────────────────────────

part of '../base/playlist_detalle_pagina.dart';

/// Contenido debajo de la cabecera: progreso + banner + lista de tracks.
List<Widget> _construirContenidoPlaylist(
  _PlaylistDetallePaginaState st,
  BuildContext context,
  DatosVistaPlaylist d,
  DetallePlaylist playlist,
  CubitLikes likedCubit,
  CubitDescargas dlCubit,
) {
  final r = Responsive(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final colorSuperficie = ColoresApp.enSuperficie(esOscuro);
  final colorBrillo =
      esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
  final loc = AppLocalizations.of(context);
  final widgets = <Widget>[];

  // Barra de progreso cuando el lote está en curso.
  if (d.estadoLote == EstadoDescarga.enProgreso) {
    widgets.add(
      Padding(
        padding: EdgeInsets.only(bottom: r.spacingS),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: d.total > 0 ? d.descargados / d.total : 0,
                minHeight: 4,
                backgroundColor: colorBrillo.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(colorBrillo),
              ),
            ),
            SizedBox(height: 4),
            Text(
              '${d.descargados} / ${d.total} ${loc.setup.miSpaceSongCount}',
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: colorBrillo.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Banner de solo-descargados sin red.
  if (!st._estaEnLinea) {
    widgets.add(
      Container(
        margin: EdgeInsets.symmetric(horizontal: r.spacingS),
        padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 6),
        decoration: BoxDecoration(
          color: colorSuperficie.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: r.footerSize - 2,
              color: colorSuperficie.withValues(alpha: 0.4),
            ),
            SizedBox(width: 6),
            Text(
              '${loc.setup.downloaded} ${loc.setup.miSpaceSongs.toLowerCase()}',
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: colorSuperficie.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Lista de tracks: cada fila resuelve su carátula/like/descarga en SU
  // build, así abrir una playlist de 100 canciones no paga el trabajo de las
  // 100 de golpe (ver FilaTrackDetalle).
  for (final item in d.items) {
    widgets.add(
      FilaTrackDetalle(
        key: ValueKey('pl_${d.src}_${item.id}'),
        item: item,
        contexto: d.items,
        subtitulo: item.artists ?? '',
        src: d.src,
        caratulaRespaldo: d.caratula,
      ),
    );
  }
  return widgets;
}
