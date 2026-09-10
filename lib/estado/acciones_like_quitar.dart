// ─────────────────────────────────────────────────────────────
// acciones_like_quitar.dart — PART de cubit_like.dart. Segunda
// parte del mixin de likes: quitar like (optimista), borrar la
// carátula local solo si nada más la muestra (descargas), y el sync
// de tracks de álbumes/playlists likeados hacia drift.
// Se conecta con: caches (favoritos/detalle/reproducción) +
// backend Go (deleteCover/fetchAlbumDetail/fetchPlaylistDetail).
// Parte del flujo: botones de like en toda la app.
// ─────────────────────────────────────────────────────────────

part of 'cubit_like.dart';

/// Parte 2: quitar like, borrado de carátulas y sync de tracks.
/// `on AccionesLike` garantiza acceso a sus miembros (backend, _fav, ...).
mixin AccionesLikeQuitar on AccionesLike {
  DownloadDao? _daoDescargas;
  DownloadDao get _downloadDao => _daoDescargas ??= DownloadDao(di.sl<AppDatabase>());

  /// Implementación del método abstracto declarado en [AccionesLike].
  @override
  @protected
  Future<void> quitarLike(ItemFeed item, String fp) async {
    if (item.coverUrl != null && item.coverUrl!.isNotEmpty) {
      // Solo borra la portada si nada la sigue mostrando: los tracks miran el
      // historial de descargas, y los álbumes/playlists miran si aún existe el
      // batch descargado (un like de un álbum descargado conserva su portada
      // en Mi Espacio aunque se quite el corazón).
      final aunNecesaria = item.type == 'track'
          ? await _estaTrackDescargado(item)
          : await _estaColeccionDescargada(item.type, item.id, item.source ?? '');
      if (!aunNecesaria) {
        unawaited(backend.deleteCover(item.coverUrl!));
      }
    }

    final huellasMuertas = <String>{fp};
    // Quitar también el fingerprint por ISRC para que el corazón se apague en
    // TODAS las extensiones donde aparezca la misma grabación.
    if (item.type == 'track' && item.isrc != null && item.isrc!.isNotEmpty) {
      huellasMuertas.add(huellaIsrc(item.isrc!));
    }
    final existente = _itemAmadoPorHuella(item);
    if (existente != null) {
      final efp = _huellaParaTipo(existente);
      if (efp != null && efp != fp) huellasMuertas.add(efp);
    }

    final nuevasHuellas = Set<String>.from(state.huellasAmadas)..removeAll(huellasMuertas);
    final nuevosItems = Map<String, DatosItemAmado>.from(state.todosAmados)..remove(item.id);

    emit(state.copiarCon(huellasAmadas: nuevasHuellas, todosAmados: nuevosItems));

    _invalidarCacheDetalle(item.id, item.type);

    switch (item.type) {
      case 'track':
        unawaited(_fav.alternarTrackAmado(
          trackId: item.id,
          trackName: item.name,
          artistName: item.artists ?? '',
          liked: false,
        ));
      case 'album':
        unawaited(_fav.alternarAlbumFavorito(
          albumId: item.id,
          name: item.name,
          artistId: item.artists ?? '',
          artistName: item.artists ?? '',
          coverUrl: item.coverUrl ?? '',
          liked: false,
        ));
      case 'artist':
        unawaited(_fav.alternarArtistaFavorito(
          artistId: item.id,
          name: item.name,
          imageUrl: item.coverUrl ?? '',
          liked: false,
        ));
      case 'playlist':
        unawaited(_fav.alternarPlaylistFavorita(
          playlistId: item.id,
          name: item.name,
          coverUrl: item.coverUrl,
          liked: false,
        ));
    }
  }

  /// Verifica si un track está descargado consultando el historial por ISRC
  /// o nombre+artista (equivalente confiable al estado en memoria del cubit).
  Future<bool> _estaTrackDescargado(ItemFeed item) async {
    try {
      final existentes = await _downloadDao.findExisting(
        isrc: item.isrc,
        trackName: item.name,
        artistName: item.artists,
      );
      return existentes.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// true cuando el álbum/playlist [type] [id] todavía tiene un batch
  /// descargado (su carátula se sigue mostrando en Mi Espacio). Reintenta con
  /// source vacío porque el batch puede estar guardado con otro nombre de
  /// extensión.
  Future<bool> _estaColeccionDescargada(String type, String id, String source) async {
    try {
      final normalizado = normalizarId(id);
      var batch = await _downloadDao.getBatchByItem(type, normalizado, source);
      if (batch == null && source.isNotEmpty) {
        batch = await _downloadDao.getBatchByItem(type, normalizado, '');
      }
      return batch != null;
    } catch (_) {
      return false;
    }
  }

  DatosItemAmado? _itemAmadoPorHuella(ItemFeed item) {
    final fp = huellaItem(item);
    return state.todosAmados.values.where((v) {
      final vfp = _huellaParaTipo(v);
      return vfp == fp;
    }).firstOrNull;
  }

  String? _huellaParaTipo(DatosItemAmado item) {
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
    return huellaItem(feedItem);
  }
}