// ─────────────────────────────────────────────────────────────
// playlist_detalle_calculos.dart — PART de playlist_detalle_pagina.dart:
// cálculo de los datos de la vista — fuente (propia, del track o
// del lote), estado del lote, contador de tracks descargados,
// detección de archivos locales (para el botón exportar), mejor
// carátula (like local primero, luego huella, luego propios) y los
// items visibles de tracks (filtro offline: solo descargados).
// Se conecta con: playlist_detalle_pagina.dart (misma library) +
// cubit_like + cubit_descargas.
// Parte del flujo: Detalle → playlist (cálculos de la vista).
// ─────────────────────────────────────────────────────────────

part of 'playlist_detalle_pagina.dart';

/// Calcula todos los datos que la vista de playlist necesita.
DatosVistaPlaylist _calcularDatosPlaylist(
  _PlaylistDetallePaginaState st,
  BuildContext context,
  DetallePlaylist playlist,
  CubitLikes likedCubit,
  CubitDescargas dlCubit,
) {
  // Fuente: la del widget, la del primer track o la del lote.
  var src = st.widget.source.isNotEmpty
      ? st.widget.source
      : (playlist.tracks.isNotEmpty ? (playlist.tracks.first.provider ?? '') : '');
  if (src.isEmpty) {
    final fuenteLote = dlCubit.buscarFuenteLote('playlist', playlist.id);
    if (fuenteLote.isNotEmpty) src = fuenteLote;
  }

  final estadoLote = dlCubit
      .estadoDescargaPara('playlist_${normalizarIdTrack(playlist.id)}_$src')
      .estado;

  // Conteo de tracks descargados para el badge y la barra de progreso.
  int descargados = 0;
  for (final t in playlist.tracks) {
    final clave = 'track_${normalizarIdTrack(t.trackId)}_$src';
    if (dlCubit.estadoDescargaPara(clave).estado ==
        EstadoDescarga.completado) {
      descargados++;
    }
  }
  final total = playlist.tracks.length;
  final todosDescargados = descargados >= total && total > 0;
  final hayArchivosLocales = playlist.tracks.any(
    (t) => t.filePath != null && t.filePath!.isNotEmpty,
  );

  // Carátula: like por ID (ruta local primero), luego huella, luego propios.
  final amada = likedCubit.itemAmadoPorId(playlist.id);
  final caratulaAmada = amada?.rutaCaratulaLocal ?? amada?.coverUrl;
  final caratula = caratulaAmada ??
      likedCubit.caratulaLocalPara(ItemFeed(
        id: playlist.id,
        type: 'playlist',
        name: playlist.name,
        coverUrl: st.widget.coverUrl,
      )) ??
      st.widget.coverUrl;

  // Items visibles: online todos; offline solo los descargados.
  final items = playlist.tracks
      .where((t) {
        if (st._estaEnLinea) return true;
        if (t.isDownloaded) return true;
        final clave = 'track_${normalizarIdTrack(t.trackId)}_$src';
        return dlCubit.estadoDescargaPara(clave).estado ==
            EstadoDescarga.completado;
      })
      .map((t) {
        final caratulaTrack = (t.coverUrl?.isNotEmpty == true)
            ? t.coverUrl!
            : ((playlist.coverPath?.isNotEmpty == true)
                ? playlist.coverPath!
                : st.widget.coverUrl);
        return ItemFeed(
          id: t.trackId,
          type: 'track',
          name: t.name,
          artists: t.artistName,
          coverUrl: caratulaTrack,
          albumName: t.albumName,
          durationMs: t.durationMs,
          isrc: t.isrc,
          source: src,
          spotifyId: t.spotifyId,
          deezerId: t.deezerId,
          tidalId: t.tidalId,
          qobuzId: t.qobuzId,
        );
      })
      .toList();

  return (
    src: src,
    estadoLote: estadoLote,
    descargados: descargados,
    total: total,
    todosDescargados: todosDescargados,
    hayArchivosLocales: hayArchivosLocales,
    caratula: caratula,
    items: items,
  );
}