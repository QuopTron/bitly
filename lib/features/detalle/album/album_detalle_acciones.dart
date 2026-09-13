// ─────────────────────────────────────────────────────────────
// PART de album_detalle_pagina.dart: acciones de cabecera (botones
// vidrio like/descargar/reproducir) y descarga batch por calidad.
// Conecta: album_detalle_pagina + boton_accion_vidrio + cubits.
// ─────────────────────────────────────────────────────────────

part of 'album_detalle_pagina.dart';

/// Fila de botones de la cabecera: like, descargar y reproducir.
Widget _filaAcciones(
  _AlbumDetallePaginaState st,
  BuildContext context,
  DatosVistaAlbum d,
  DetalleAlbum album,
  bool esAmado,
  CubitLikes likedCubit,
) {
  final r = Responsive(context);
  final itemAlbum = ItemFeed(
    id: album.id,
    type: 'album',
    name: album.name,
    artists: album.artistName,
    coverUrl: d.caratula,
  );
  final loteListo = d.estadoLote == EstadoDescarga.completado ||
      d.todosDescargados;
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // Like del álbum.
      BotonAccionVidrio(
        icono: esAmado ? Icons.favorite : Icons.favorite_border,
        color: esAmado ? Colors.red : null,
        onTap: () => likedCubit.alternarLike(itemAlbum),
      ),
      SizedBox(width: r.spacingS),
      // Descarga del álbum completo.
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
            ? () => _descargarAlbumCompleto(st)
            : null,
      ),
      SizedBox(width: r.spacingS),
      // Reproducir el álbum desde el primer track visible.
      BotonAccionVidrio(
        icono: Icons.play_arrow_rounded,
        relleno: true,
        onTap: d.items.isNotEmpty
            ? () => sl<CubitCola>().reproducirConContexto(d.items, d.items.first)
            : null,
      ),
    ],
  );
}

/// Badge de la cabecera: total de canciones + tipo + estado de descarga.
String _construirBadge(
  DatosVistaAlbum d,
  DetalleAlbum album,
  AppLocalizations loc,
) {
  final base = '${album.totalTracks} ${loc.setup.miSpaceSongCount}'
      '  •  ${album.albumType ?? ''}';
  if (d.todosDescargados) return '$base  •  ✓ ${loc.setup.downloaded}';
  if (d.descargados > 0) {
    return '$base  •  ${d.descargados}/${d.total}'
        ' ${loc.setup.downloaded.toLowerCase()}';
  }
  return base;
}

/// Descarga el álbum completo: solo tracks pendientes, con calidad elegida.
Future<void> _descargarAlbumCompleto(_AlbumDetallePaginaState st) async {
  final album = st._album;
  if (album == null || album.tracks.isEmpty) return;
  final dlCubit = st.context.read<CubitDescargas>();
  final esOscuro = Theme.of(st.context).brightness == Brightness.dark;
  final ajustes = await sl<CacheAjustes>().getAjustesDescarga();
  final src = st.widget.source.isNotEmpty
      ? st.widget.source
      : (album.tracks.first.provider ?? '');
  final caratula = st._caratulaAlbumResuelta ??
      album.coverUrl ??
      st.widget.coverUrl;

  // Solo tracks que aún no están completados.
  final tracks = album.tracks
      .where((t) {
        final clave = 'track_${normalizarIdTrack(t.trackId)}_$src';
        return dlCubit.estadoDescargaPara(clave).estado !=
            EstadoDescarga.completado;
      })
      .map((t) => <String, dynamic>{
            'track_id': t.trackId,
            'track_title': t.name,
            'artist_name': (t.artistName?.isNotEmpty == true)
                ? t.artistName!
                : (album.artistName ?? ''),
            'album_name': (t.albumName?.isNotEmpty == true)
                ? t.albumName!
                : album.name,
            'source': src,
            'isrc': t.isrc,
            'duration_ms': t.durationMs,
            'cover_url': (t.coverUrl?.isNotEmpty == true)
                ? t.coverUrl!
                : caratula,
          })
      .toList();

  if (tracks.isEmpty || !st.mounted) return;

  // Hoja de opciones en modo batch: la calidad elegida inicia el lote.
  await showModalBottomSheet(
    context: st.context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => HojaOpcionesDescarga(
      item: ItemFeed(
        id: album.id,
        type: 'album',
        name: album.name,
        artists: album.artistName,
        coverUrl: caratula,
        source: src,
      ),
      esOscuro: esOscuro,
      ajustes: ajustes,
      onCalidadSeleccionada: (calidad) {
        dlCubit.iniciarDescargaAlbum(
          album.id,
          tracks,
          ajustes: ajustes,
          source: src,
          calidadForzada: calidad,
        );
      },
    ),
  );
}