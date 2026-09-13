// ─────────────────────────────────────────────────────────────
// album_detalle_calculos.dart — PART de album_detalle_pagina.dart:
// cálculo de los datos de la vista — fuente (propia o del lote),
// estado del lote, contador de tracks descargados, mejor carátula
// (like local primero, luego huella, luego propios) y los items
// visibles de tracks (filtro offline: solo descargados sin red).
// Se conecta con: album_detalle_pagina.dart (misma library) +
// cubit_like + cubit_descargas.
// Parte del flujo: Detalle → álbum (cálculos de la vista).
// ─────────────────────────────────────────────────────────────

part of 'album_detalle_pagina.dart';

/// Calcula todos los datos que la vista de álbum necesita.
DatosVistaAlbum _calcularDatosVista(
  _AlbumDetallePaginaState st,
  BuildContext context,
  DetalleAlbum album,
  CubitLikes likedCubit,
  CubitDescargas dlCubit,
) {
  // Fuente: la del widget, la del primer track o la del lote.
  var src = st.widget.source.isNotEmpty
      ? st.widget.source
      : (album.tracks.isNotEmpty ? (album.tracks.first.provider ?? '') : '');
  if (src.isEmpty) {
    final fuenteLote = dlCubit.buscarFuenteLote('album', album.id);
    if (fuenteLote.isNotEmpty) src = fuenteLote;
  }

  final estadoLote =
      dlCubit.estadoDescargaPara('album_${normalizarIdTrack(album.id)}_$src').estado;

  // Conteo de tracks descargados para el badge y la barra de progreso.
  int descargados = 0;
  for (final t in album.tracks) {
    final clave = 'track_${normalizarIdTrack(t.trackId)}_$src';
    if (dlCubit.estadoDescargaPara(clave).estado ==
        EstadoDescarga.completado) {
      descargados++;
    }
  }
  final total = album.tracks.length;
  final todosDescargados = descargados >= total && total > 0;

  // Carátula: like por ID (ruta local primero), luego huella, luego propios.
  final amado = likedCubit.itemAmadoPorId(album.id);
  final caratulaAmada = amado?.rutaCaratulaLocal ?? amado?.coverUrl;
  final caratula = caratulaAmada ??
      likedCubit.caratulaLocalPara(ItemFeed(
        id: album.id,
        type: 'album',
        name: album.name,
        artists: album.artistName,
        coverUrl: album.coverUrl,
      )) ??
      album.coverUrl ??
      st.widget.coverUrl;

  // Items visibles: online todos; offline solo los descargados.
  final items = album.tracks
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
            : ((album.coverUrl?.isNotEmpty == true) ? album.coverUrl! : null);
        return ItemFeed(
          id: t.trackId,
          type: 'track',
          name: t.name,
          artists: t.artistName,
          coverUrl: caratulaTrack,
          albumName: album.name,
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
    caratula: caratula,
    items: items,
  );
}