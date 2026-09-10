// ─────────────────────────────────────────────────────────────
// artista_detalle_calculos.dart — PART de artista_detalle_pagina.dart:
// cálculo de los datos de la vista — imagen (ruta local primero),
// subtítulo con conteos de tracks/álbumes, items de tracks y álbumes
// con su fuente, y tracks offline (likes que coinciden con el nombre
// del artista para reproducir sin red).
// Se conecta con: artista_detalle_pagina.dart (misma library) +
// cubit_like + cubit_descargas.
// Parte del flujo: Detalle → artista (cálculos de la vista).
// ─────────────────────────────────────────────────────────────

part of 'artista_detalle_pagina.dart';

/// Calcula todos los datos que la vista de artista necesita.
DatosVistaArtista _calcularDatosArtista(
  _ArtistaDetallePaginaState st,
  BuildContext context,
  DetalleArtista artista,
  CubitLikes likedCubit,
  CubitDescargas dlCubit,
) {
  // Imagen del artista: ruta local primero, luego URL remota.
  final imagen = (artista.imagePath?.isNotEmpty == true)
      ? artista.imagePath
      : (artista.imageUrl?.isNotEmpty == true ? artista.imageUrl : null);

  // Tracks top con su fuente (la del widget o la del track).
  final tracks = artista.topTracks.map((t) {
    final src = st.widget.source.isNotEmpty ? st.widget.source : (t.provider ?? '');
    return ItemFeed(
      id: t.trackId,
      type: 'track',
      name: t.name,
      coverUrl: t.coverUrl,
      artists: artista.name,
      source: src,
      albumName: t.albumName,
      durationMs: t.durationMs,
      isrc: t.isrc,
      spotifyId: t.spotifyId,
      deezerId: t.deezerId,
      tidalId: t.tidalId,
      qobuzId: t.qobuzId,
    );
  }).toList();

  // Álbumes top con la fuente del widget.
  final albums = artista.topAlbums.map((a) {
    return ItemFeed(
      id: a.albumId,
      type: 'album',
      name: a.name,
      coverUrl: a.coverUrl,
      source: st.widget.source,
    );
  }).toList();

  // Tracks offline: likes cuyo artista coincide con el nombre buscado.
  final tracksOffline = likedCubit.tracks
      .where((t) =>
          t.artists?.toLowerCase().contains(st.widget.artistName.toLowerCase()) ??
          false)
      .map((t) => ItemFeed(
            id: t.id,
            type: 'track',
            name: t.name,
            artists: t.artists,
            coverUrl: t.coverUrl,
            albumName: t.albumName,
            durationMs: t.durationMs,
            isrc: t.isrc,
            source: t.source ?? st.widget.source,
          ))
      .toList();

  // Subtítulo: conteos de tracks y álbumes, unidos con un punto.
  final loc = AppLocalizations.of(context);
  final partes = <String>[
    if (artista.topTracks.isNotEmpty)
      '${artista.topTracks.length} ${loc.setup.searchTracks}',
    if (artista.topAlbums.isNotEmpty)
      '${artista.topAlbums.length} ${loc.setup.searchAlbums}',
  ];
  final subtitulo = partes.join(' • ');

  return (
    imagen: imagen,
    subtitulo: subtitulo,
    tracks: tracks,
    albums: albums,
    tracksOffline: tracksOffline,
  );
}