// ─────────────────────────────────────────────────────────────
// like_sync_tracks.dart — PART de cubit_like.dart. Sincroniza los
// tracks de un álbum/playlist recién likeado hacia drift: fetch del
// detalle a Go, upsert de tracks con sus carátulas locales y
// relleno de la carátula del item padre si no tenía una.
// Se conecta con: backend Go (fetchAlbumDetail/fetchPlaylistDetail/
// saveCover) + ReproduccionSync + ContentDao.
// Parte del flujo: like de álbumes/playlists.
// ─────────────────────────────────────────────────────────────

part of 'cubit_like.dart';

/// Sync de tracks de álbumes/playlists likeados hacia drift.
mixin LikeSyncTracks on AccionesLike {
  /// Fetch del detalle de álbum a Go y guarda los tracks con carátulas en la
  /// base de contenido (respaldo del like de álbum).
  @override
  Future<void> sincronizarTracksAlbum(String albumId, String source, String artistName, {String? coverUrlPadre}) async {
    String? caratulaSincronizada;
    try {
      final json = await backend.fetchAlbumDetail(albumId, source);
      if (json.isEmpty || json == '{}') return;
      final detalle = DetalleAlbum.desdeJson(jsonDecode(json) as Map<String, dynamic>);
      await _pb.sincronizarDetalleAlbum(detalle, fuente: source);
      for (final t in detalle.tracks) {
        final cover = t.coverUrl?.isNotEmpty == true ? t.coverUrl : coverUrlPadre;
        if (cover != null && cover.isNotEmpty) {
          final ruta = await _guardarCaratula(cover);
          if (ruta != null) {
            caratulaSincronizada ??= ruta;
            await _contentDao.upsertTrack(TracksCompanion(
              id: Value(t.trackId),
              name: Value(t.name),
              artistId: Value(t.trackId),
              coverPath: Value(ruta),
              durationMs: Value(t.durationMs),
              trackNumber: Value(t.trackNumber),
              isrc: Value(t.isrc),
              source: Value(t.provider ?? source),
              createdAt: Value(DateTime.now()),
            ));
          }
        }
      }
    } catch (_) {}
    _rellenarCaratulaLocal(albumId, caratulaSincronizada);
  }

  /// Fetch del detalle de playlist a Go y guarda los tracks con carátulas.
  @override
  Future<void> sincronizarTracksPlaylist(String playlistId, String source, {String? coverUrlPadre}) async {
    String? caratulaSincronizada;
    try {
      final json = await backend.fetchPlaylistDetail(playlistId, source);
      if (json.isEmpty || json == '{}') return;
      final detalle = DetallePlaylist.desdeJson(jsonDecode(json) as Map<String, dynamic>);
      await _pb.sincronizarDetallePlaylist(detalle, fuente: source);
      for (final t in detalle.tracks) {
        final cover = t.coverUrl?.isNotEmpty == true ? t.coverUrl : coverUrlPadre;
        if (cover != null && cover.isNotEmpty) {
          final ruta = await _guardarCaratula(cover);
          if (ruta != null) {
            caratulaSincronizada ??= ruta;
            await _contentDao.upsertTrack(TracksCompanion(
              id: Value(t.trackId),
              name: Value(t.name),
              artistId: Value(t.trackId),
              coverPath: Value(ruta),
              durationMs: Value(t.durationMs),
              trackNumber: Value(t.trackNumber),
              isrc: Value(t.isrc),
              source: Value(t.provider ?? source),
              createdAt: Value(DateTime.now()),
            ));
          }
        }
      }
    } catch (_) {}
    _rellenarCaratulaLocal(playlistId, caratulaSincronizada);
  }

  /// Si el like del álbum/playlist padre no obtuvo carátula local (p.ej. su
  /// saveCover inicial falló), adopta la primera carátula de track
  /// sincronizada para que la tarjeta muestre arte local en vez de gris.
  void _rellenarCaratulaLocal(String id, String? coverPath) {
    if (coverPath == null || coverPath.isEmpty) return;
    final actual = state.todosAmados[id];
    if (actual == null || (actual.rutaCaratulaLocal?.isNotEmpty == true)) return;
    final nuevosItems = Map<String, DatosItemAmado>.from(state.todosAmados);
    nuevosItems[id] = actual.copiarCon(rutaCaratulaLocal: coverPath);
    emit(state.copiarCon(todosAmados: nuevosItems));
    switch (actual.type) {
      case 'album':
        unawaited(_fav.actualizarCaratulaAlbum(id, coverPath));
      case 'playlist':
        unawaited(_fav.actualizarCaratulaPlaylist(id, coverPath));
      case 'track':
        unawaited(_fav.actualizarCaratulaTrack(id, coverPath));
      case 'artist':
        unawaited(_fav.actualizarImagenArtista(id, coverPath));
    }
  }
}