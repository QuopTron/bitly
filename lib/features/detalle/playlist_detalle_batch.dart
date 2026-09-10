// ─────────────────────────────────────────────────────────────
// playlist_detalle_batch.dart — PART de playlist_detalle_pagina.dart:
// descarga la playlist completa en modo batch: solo tracks
// pendientes, con la hoja de opciones (calidad elegida → inicia
// el lote vía iniciarDescargaPlaylist) y la exportación a archivos
// con feedback en SnackBar.
// Se conecta con: hoja_opciones_descarga + exportacion_playlist_ui.
// Parte del flujo: Detalle → playlist (batch/exportar).
// ─────────────────────────────────────────────────────────────

part of 'playlist_detalle_pagina.dart';

/// Descarga la playlist completa: solo tracks pendientes, con calidad.
Future<void> _descargarPlaylistCompleta(_PlaylistDetallePaginaState st) async {
  final playlist = st._playlist;
  if (playlist == null || playlist.tracks.isEmpty) return;
  final dlCubit = st.context.read<CubitDescargas>();
  final esOscuro = Theme.of(st.context).brightness == Brightness.dark;
  final ajustes = await sl<CacheAjustes>().getAjustesDescarga();
  final src = st.widget.source.isNotEmpty
      ? st.widget.source
      : (playlist.tracks.first.provider ?? '');
  final caratula = st._caratulaResuelta ?? st.widget.coverUrl;

  // Solo tracks que aún no están completados.
  final tracks = playlist.tracks
      .where((t) {
        final clave = 'track_${normalizarIdTrack(t.trackId)}_$src';
        return dlCubit.estadoDescargaPara(clave).estado !=
            EstadoDescarga.completado;
      })
      .map((t) => <String, dynamic>{
            'track_id': t.trackId,
            'track_title': t.name,
            'artist_name': t.artistName ?? '',
            'album_name': t.albumName ?? '',
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
        id: playlist.id,
        type: 'playlist',
        name: playlist.name,
        coverUrl: caratula,
        source: src,
      ),
      esOscuro: esOscuro,
      ajustes: ajustes,
      onCalidadSeleccionada: (calidad) {
        dlCubit.iniciarDescargaPlaylist(
          playlist.id,
          tracks,
          ajustes: ajustes,
          source: src,
          calidadForzada: calidad,
        );
      },
    ),
  );
}

/// Exporta la playlist a archivos (M3U/CUE/NFO) con feedback en SnackBar.
Future<void> _exportarPlaylist(
  _PlaylistDetallePaginaState st,
  DetallePlaylist playlist,
) async {
  final context = st.context;
  final directorioInicial = await sl<CacheAjustes>().getRutaDescargas();
  if (!context.mounted) return;
  await exportarConSnack(
    context: context,
    name: playlist.name,
    tracks: playlist.tracks,
    initialDirectory: directorioInicial,
  );
}