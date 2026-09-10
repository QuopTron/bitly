// ─────────────────────────────────────────────────────────────
// playlist_detalle_contenido.dart — PART de playlist_detalle_pagina.dart:
// children de la cabecera — barra de progreso del lote en curso,
// banner de solo-descargados sin red y la lista de tracks con
// like/descarga/borrar/reproducir/compartir y la carátula resuelta.
// Se conecta con: playlist_detalle_pagina.dart (misma library) +
// tarjeta_track + hoja_opciones_descarga + share_plus.
// Parte del flujo: Detalle → playlist (contenido).
// ─────────────────────────────────────────────────────────────

part of 'playlist_detalle_pagina.dart';

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
    widgets.add(Padding(
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
    ));
  }

  // Banner de solo-descargados sin red.
  if (!st._estaEnLinea) {
    widgets.add(Container(
      margin: EdgeInsets.symmetric(horizontal: r.spacingS),
      padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 6),
      decoration: BoxDecoration(
        color: colorSuperficie.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off,
            size: r.footerSize - 2,
            color: colorSuperficie.withValues(alpha: 0.4)),
        SizedBox(width: 6),
        Text(
          '${loc.setup.downloaded} ${loc.setup.miSpaceSongs.toLowerCase()}',
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: colorSuperficie.withValues(alpha: 0.4),
          ),
        ),
      ]),
    ));
  }

  // Lista de tracks visibles.
  for (final item in d.items) {
    final clave = 'track_${normalizarIdTrack(item.id)}_${d.src}';
    final caratulaItem = likedCubit.caratulaLocalPara(item) ?? d.caratula;
    final esAmado = likedCubit.estaAmado(item);
    void play() => sl<CubitCola>().reproducirConContexto(d.items, item);
    widgets.add(Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingS,
        vertical: r.spacingXS * 0.5,
      ),
      child: TarjetaTrack(
        titulo: item.name,
        subtitulo: item.artists ?? '',
        coverUrl: caratulaItem,
        esAmado: esAmado,
        readyKey: normalizarIdTrack(item.id),
        escalaTexto: 1.2,
        onLike: () => likedCubit.alternarLike(item),
        estadoDescarga: dlCubit.estadoDescargaPara(clave).estado,
        onDescargar: () => mostrarOpcionesDescarga(context, item, esOscuro),
        onBorrar: () => dlCubit.borrarDescargaTrack(item.id, d.src),
        onTap: play,
        onCompartir: () => SharePlus.instance.share(ShareParams(
              text: item.albumName != null
                  ? '🎵 ${item.name} — ${item.artists ?? ''}\n💿 ${item.albumName}'
                  : '🎵 ${item.name} — ${item.artists ?? ''}',
            )),
      ),
    ));
  }
  return widgets;
}