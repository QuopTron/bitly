// ─────────────────────────────────────────────────────────────
// like_quitar_por_id.dart — PART de cubit_like.dart. Quitar el like
// de un item conociendo solo su id/tipo/nombre (desde la UI de Mi
// Espacio → Favoritos), con borrado condicional de la carátula
// local si nada más la muestra.
// Se conecta con: backend Go (deleteCover) + CacheFavoritos.
// Parte del flujo: quitar favoritos desde listas por id.
// ─────────────────────────────────────────────────────────────

part of 'cubit_like.dart';

/// Quitar like por id (desde listas de favoritos).
/// `on AccionesLikeQuitar` da acceso a los helpers de verificación de
/// descargas y huellas.
mixin LikeQuitarPorId on AccionesLikeQuitar {
  Future<void> quitarLikePorId(String id, String type, String name, String? artists, String? coverUrl) async {
    final fp = _huellaParaTipo(DatosItemAmado(id: id, type: type, name: name, artists: artists));

    // Usar la coverUrl ORIGINAL del estado (no la ruta local resuelta).
    final itemAmado = state.todosAmados[id];
    final coverUrlOriginal = itemAmado?.coverUrl ?? coverUrl;

    if (coverUrlOriginal != null && coverUrlOriginal.isNotEmpty) {
      if (type == 'track') {
        final track = ItemFeed(id: id, type: 'track', name: name, artists: artists, isrc: itemAmado?.isrc);
        final descargado = await _estaTrackDescargado(track);
        if (!descargado) {
          unawaited(backend.deleteCover(coverUrlOriginal));
        }
      } else {
        // Álbum/playlist: conservar la portada si todavía hay un batch
        // descargado que la muestra en Mi Espacio.
        final aunDescargado = await _estaColeccionDescargada(type, id, itemAmado?.source ?? '');
        if (!aunDescargado) {
          unawaited(backend.deleteCover(coverUrlOriginal));
        }
      }
    }

    final nuevasHuellas = Set<String>.from(state.huellasAmadas);
    if (fp != null) nuevasHuellas.remove(fp);
    final existente = state.todosAmados[id];
    if (existente != null) {
      final efp = _huellaParaTipo(existente);
      if (efp != null && efp != fp) nuevasHuellas.remove(efp);
      final isrc = existente.isrc;
      if (isrc != null && isrc.isNotEmpty) nuevasHuellas.remove(huellaIsrc(isrc));
    }
    final nuevosItems = Map<String, DatosItemAmado>.from(state.todosAmados)..remove(id);

    emit(state.copiarCon(huellasAmadas: nuevasHuellas, todosAmados: nuevosItems));

    _invalidarCacheDetalle(id, type);

    switch (type) {
      case 'track':
        unawaited(_fav.alternarTrackAmado(
          trackId: id,
          trackName: name,
          artistName: artists ?? '',
          liked: false,
        ));
      case 'album':
        unawaited(_fav.alternarAlbumFavorito(
          albumId: id,
          name: name,
          artistId: artists ?? '',
          artistName: artists ?? '',
          coverUrl: coverUrl ?? '',
          liked: false,
        ));
      case 'artist':
        unawaited(_fav.alternarArtistaFavorito(
          artistId: id,
          name: name,
          imageUrl: coverUrl ?? '',
          liked: false,
        ));
      case 'playlist':
        unawaited(_fav.alternarPlaylistFavorita(
          playlistId: id,
          name: name,
          liked: false,
        ));
    }
  }
}