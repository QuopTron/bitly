// ─────────────────────────────────────────────────────────────
// like_carga.dart — PART de cubit_like.dart. Carga inicial de los
// items amados (tracks/álbumes/artistas/playlists) desde drift y
// construcción de las huellas (incluyendo ISRC para matching
// cross-extensión).
// Se conecta con: CacheFavoritos + modelos + huella_item.
// Parte del flujo: arranque de Mi Espacio → Favoritos.
// ─────────────────────────────────────────────────────────────

part of 'cubit_like.dart';

/// Carga de favoritos desde drift hacia el estado del cubit.
/// `on AccionesLike` da acceso a `_fav` (definido en el mixin base).
mixin LikeCarga on AccionesLike {
  Future<void> cargarFavoritos() async {
    final huellas = <String>{};
    final items = <String, DatosItemAmado>{};

    await _cargarTracks(items);
    await _cargarAlbums(items);
    await _cargarArtistas(items);
    await _cargarPlaylists(items);

    for (final item in items.values) {
      final feedItem = ItemFeed(
        id: item.id,
        type: item.type,
        name: item.name,
        artists: item.artists,
        coverUrl: item.coverUrl,
        albumName: item.albumName,
        durationMs: item.durationMs,
        isrc: item.isrc,
        source: item.source,
      );
      final fp = huellaItem(feedItem);
      huellas.add(fp);
      // El fingerprint por ISRC sobrevive al reinicio: al cargar los tracks
      // likeados, también se registra su ISRC para que el mismo track visto
      // desde otra extensión muestre el corazón.
      if (item.isrc != null && item.isrc!.isNotEmpty) {
        huellas.add(huellaIsrc(item.isrc!));
      }
    }

    emit(state.copiarCon(
      huellasAmadas: huellas,
      todosAmados: items,
      cargando: false,
    ));
  }

  Future<void> _cargarTracks(Map<String, DatosItemAmado> items) async {
    final tracksJson = await _fav.getTracksAmados();
    if (tracksJson.isEmpty || tracksJson == '[]') return;
    final lista = jsonDecode(tracksJson) as List;
    for (final e in lista) {
      final m = e as Map<String, dynamic>;
      final id = (m['trackId'] ?? m['track_id'] ?? '').toString();
      items[id] = DatosItemAmado(
        id: id,
        type: 'track',
        name: (m['trackName'] ?? m['track_name'] ?? '') as String,
        artists: (m['artistName'] ?? m['artist_name'] ?? '') as String,
        coverUrl: (m['coverUrl'] ?? m['cover_url'] ?? '') as String,
        rutaCaratulaLocal: limpiarRutaCaratulaLocal(m['coverPath'] as String?),
        albumName: (m['albumName'] ?? m['album_name'] ?? '') as String,
        durationMs: (m['durationMs'] ?? m['duration_ms']) as int?,
        isrc: m['isrc'] as String?,
        source: (m['provider'] ?? '') as String?,
      );
    }
  }

  Future<void> _cargarAlbums(Map<String, DatosItemAmado> items) async {
    final albumsJson = await _fav.getAlbumesFavoritos();
    if (albumsJson.isEmpty || albumsJson == '[]') return;
    final lista = jsonDecode(albumsJson) as List;
    for (final e in lista) {
      final m = e as Map<String, dynamic>;
      final id = (m['albumId'] ?? m['album_id'] ?? '').toString();
      items[id] = DatosItemAmado(
        id: id,
        type: 'album',
        name: (m['name'] ?? '') as String,
        artists: (m['artistName'] ?? m['artist_name'] ?? '') as String,
        coverUrl: (m['coverUrl'] ?? m['cover_url'] ?? '') as String,
        rutaCaratulaLocal: limpiarRutaCaratulaLocal(m['coverPath'] as String?),
        source: (m['provider'] ?? '') as String?,
      );
    }
  }

  Future<void> _cargarArtistas(Map<String, DatosItemAmado> items) async {
    final artistasJson = await _fav.getArtistasFavoritos();
    if (artistasJson.isEmpty || artistasJson == '[]') return;
    final lista = jsonDecode(artistasJson) as List;
    for (final e in lista) {
      final m = e as Map<String, dynamic>;
      final id = (m['artistId'] ?? m['artist_id'] ?? '').toString();
      items[id] = DatosItemAmado(
        id: id,
        type: 'artist',
        name: (m['name'] ?? '') as String,
        coverUrl: (m['imageUrl'] ?? m['image_url'] ?? '') as String,
        rutaCaratulaLocal: limpiarRutaCaratulaLocal(m['imagePath'] as String?),
      );
    }
  }

  Future<void> _cargarPlaylists(Map<String, DatosItemAmado> items) async {
    final playlistsJson = await _fav.getPlaylistsLiked();
    if (playlistsJson.isEmpty || playlistsJson == '[]') return;
    final lista = jsonDecode(playlistsJson) as List;
    for (final e in lista) {
      final m = e as Map<String, dynamic>;
      final id = (m['playlistId'] ?? m['playlist_id'] ?? '').toString();
      items[id] = DatosItemAmado(
        id: id,
        type: 'playlist',
        name: (m['name'] ?? '') as String,
        coverUrl: (m['coverUrl'] ?? m['cover_url'] ?? '') as String,
        rutaCaratulaLocal: limpiarRutaCaratulaLocal(m['coverPath'] as String?),
        source: (m['provider'] ?? '') as String?,
      );
    }
  }
}