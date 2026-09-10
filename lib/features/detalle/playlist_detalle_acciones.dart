// ─────────────────────────────────────────────────────────────
// PART de playlist_detalle_pagina.dart: botones vidrio de cabecera
// (like/descargar/reproducir/exportar) y descarga batch por calidad.
// Conecta: boton_accion_vidrio + hoja_opciones + exportacion UI.
// ─────────────────────────────────────────────────────────────

part of 'playlist_detalle_pagina.dart';

/// Fila de botones de la cabecera: like, descargar, reproducir y exportar.
Widget _filaAccionesPlaylist(
  _PlaylistDetallePaginaState st,
  BuildContext context,
  DatosVistaPlaylist d,
  DetallePlaylist playlist,
  bool esAmada,
  CubitLikes likedCubit,
) {
  final r = Responsive(context);
  final itemPlaylist = ItemFeed(
    id: playlist.id,
    type: 'playlist',
    name: playlist.name,
    coverUrl: d.caratula,
    source: d.src,
  );
  final loteListo = d.estadoLote == EstadoDescarga.completado ||
      d.todosDescargados;
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // Like de la playlist.
      BotonAccionVidrio(
        icono: esAmada ? Icons.favorite : Icons.favorite_border,
        color: esAmada ? Colors.red : null,
        onTap: () => likedCubit.alternarLike(itemPlaylist),
      ),
      SizedBox(width: r.spacingS),
      // Descarga de la playlist completa.
      BotonAccionVidrio(
        icono: loteListo
            ? Icons.check_circle
            : d.estadoLote == EstadoDescarga.enProgreso
                ? Icons.hourglass_top_rounded
                : Icons.download,
        color: loteListo
            ? ColoresApp.verdeBrillante
            : d.estadoLote == EstadoDescarga.enProgreso
                ? const Color(0xFFFF9800)
                : null,
        onTap: st._estaEnLinea && !d.todosDescargados
            ? () => _descargarPlaylistCompleta(st)
            : null,
      ),
      SizedBox(width: r.spacingS),
      // Reproducir la playlist desde el primer track visible.
      BotonAccionVidrio(
        icono: Icons.play_arrow_rounded,
        relleno: true,
        onTap: d.items.isNotEmpty
            ? () => sl<CubitCola>().reproducirConContexto(d.items, d.items.first)
            : null,
      ),
      // Exportar a archivos (solo si hay tracks con ruta local).
      if (d.hayArchivosLocales) ...[
        SizedBox(width: r.spacingS),
        BotonAccionVidrio(
          icono: Icons.file_download_outlined,
          onTap: () => _exportarPlaylist(st, playlist),
        ),
      ],
    ],
  );
}

/// Badge de la cabecera: total de canciones + estado de descarga.
String _construirBadgePlaylist(
  DatosVistaPlaylist d,
  DetallePlaylist playlist,
  AppLocalizations loc,
) {
  final base = '${playlist.itemCount} ${loc.setup.miSpaceSongCount}';
  if (d.todosDescargados) return '$base  •  ✓ ${loc.setup.downloaded}';
  if (d.descargados > 0) {
    return '$base  •  ${d.descargados}/${d.total}'
        ' ${loc.setup.downloaded.toLowerCase()}';
  }
  return base;
}