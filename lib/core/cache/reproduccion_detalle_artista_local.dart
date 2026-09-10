// ─────────────────────────────────────────────────────────────
// reproduccion_detalle_artista_local.dart — PART de
// reproduccion_detalle_local.dart: construye el detalle de artista
// (top tracks, top álbumes, similares) desde las tablas drift
// LOCALES (offline / respaldo sin red).
// Se conecta con: ContentDao + PlayHistoryDao + modelos de detalle.
// Parte del flujo: detalle de artista (local/offline).
// ─────────────────────────────────────────────────────────────

part of 'reproduccion_detalle_local.dart';

/// Mixin con el detalle de artista local, aplicado en ReproduccionDetalleLocal.
mixin ReproduccionDetalleArtistaLocal {
  /// DAO de contenido (lo provee la clase base ReproduccionDetalleLocal).
  ContentDao get _contenido;

  /// DAO de historial (lo provee la clase base ReproduccionDetalleLocal).
  PlayHistoryDao get _historial;

  /// Top tracks de un artista ordenados por nº de plays descendente.
  Future<List<TrackDetalle>> getTopTracksArtista(String artistId, {int limit = 20}) async {
    final tracks = await _contenido.getTracksByArtist(artistId);
    final aggs = await _historial.getTop('track', limit: 1000);
    final mapaPlays = {for (final a in aggs) a.itemId: a.playCount ?? 0};

    final ordenado = tracks.map((t) {
      final pc = mapaPlays[t.id] ?? 0;
      return (track: t, playCount: pc);
    }).toList()..sort((a, b) {
      final cmp = b.playCount.compareTo(a.playCount);
      if (cmp != 0) return cmp;
      return a.track.name.compareTo(b.track.name);
    });

    return ordenado.take(limit).map((e) => TrackDetalle(
      trackId: e.track.id,
      name: e.track.name,
      durationMs: e.track.durationMs ?? 0,
      trackNumber: e.track.trackNumber ?? 0,
      isrc: e.track.isrc ?? '',
      coverUrl: e.track.coverUrl,
      coverPath: e.track.coverPath,
      provider: e.track.source,
    )).toList();
  }

  /// Top álbumes de un artista ordenados por nº de plays descendente.
  Future<List<DetalleAlbumLigero>> getTopAlbumesArtista(String artistId, {int limit = 10}) async {
    final albums = await _contenido.getAlbumsByArtist(artistId);
    final aggs = await _historial.getTop('album', limit: 1000);
    final mapaPlays = {for (final a in aggs) a.itemId: a.playCount ?? 0};

    final ordenado = albums.map((a) {
      final pc = mapaPlays[a.id] ?? 0;
      return (album: a, playCount: pc);
    }).toList()..sort((a, b) {
      final cmp = b.playCount.compareTo(a.playCount);
      if (cmp != 0) return cmp;
      return (a.album.releaseDate ?? '').compareTo(b.album.releaseDate ?? '');
    });

    return ordenado.take(limit).map((e) => DetalleAlbumLigero(
      albumId: e.album.id,
      name: e.album.name,
      coverUrl: e.album.coverUrl,
      coverPath: e.album.coverPath,
      releaseDate: e.album.releaseDate,
      totalTracks: e.album.totalTracks ?? 0,
      playCount: e.playCount,
    )).toList();
  }

  /// Artistas similares desde la tabla drift SimilarArtists.
  Future<List<Map<String, dynamic>>> getArtistasSimilares(String artistId) async {
    final similares = await _contenido.getSimilarArtists(artistId);
    final resultado = <Map<String, dynamic>>[];
    for (final s in similares) {
      final artista = await _contenido.getArtist(s.similarArtistId);
      resultado.add({
        'artistId': s.similarArtistId,
        'artistName': artista?.name ?? '',
        'imageUrl': artista?.imageUrl ?? '',
        'imagePath': artista?.imagePath ?? '',
        'score': s.similarityScore ?? 0.0,
      });
    }
    return resultado;
  }

  /// Arma un DetalleArtista completo desde drift local, o null si no existe.
  Future<DetalleArtista?> getDetalleArtistaLocal(String artistId) async {
    final artista = await _contenido.getArtist(artistId);
    if (artista == null) return null;
    final topTracks = await getTopTracksArtista(artistId);
    final topAlbums = await getTopAlbumesArtista(artistId);
    return DetalleArtista(
      id: artista.id,
      name: artista.name,
      imageUrl: artista.imageUrl,
      imagePath: artista.imagePath,
      topTracks: topTracks,
      topAlbums: topAlbums,
    );
  }
}