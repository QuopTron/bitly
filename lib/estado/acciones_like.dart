// ─────────────────────────────────────────────────────────────
// acciones_like.dart — PART de cubit_like.dart. Acciones de dar
// like: actualización optimista del estado, persistencia en
// favoritos (drift) y sync de carátulas locales en segundo plano
// (best-effort, sin bloquear el like).
// Se conecta con: caches (favoritos/detalle) + backend Go
// (saveCover/getCoverPathForTrack).
// Parte del flujo: botones de like en toda la app.
// ─────────────────────────────────────────────────────────────

part of 'cubit_like.dart';

/// Acciones de like (optimistas + persistencia + carátulas).
/// Los métodos de quitar-like y sync de tracks se implementan en
/// [AccionesLikeQuitar] (mixin combinado después en CubitLikes).
mixin AccionesLike on Cubit<EstadoLikes> {
  BackendService get backend;
  CacheFavoritos get _fav => di.sl<CacheFavoritos>();
  CacheDetalle get _cacheDetalle => di.sl<CacheDetalle>();
  ReproduccionSync get _pb => di.sl<ReproduccionSync>();

  ContentDao? _daoContenido;
  ContentDao get _contentDao => _daoContenido ??= ContentDao(di.sl<AppDatabase>());

  /// Implementado por [LikeCaratulas] (mixin combinado en CubitLikes).
  @protected
  Future<String?> _guardarCaratula(String coverUrl);

  /// Implementado por [LikeCaratulas].
  @protected
  Future<void> _guardarCaratulaParaLike(ItemFeed item, String fp);

  /// Implementado por [AccionesLikeQuitar] (mixin combinado en CubitLikes).
  @protected
  Future<void> quitarLike(ItemFeed item, String fp);

  /// Implementado por [AccionesLikeQuitar].
  @protected
  Future<void> sincronizarTracksAlbum(String albumId, String source, String artistName, {String? coverUrlPadre});

  /// Implementado por [AccionesLikeQuitar].
  @protected
  Future<void> sincronizarTracksPlaylist(String playlistId, String source, {String? coverUrlPadre});

  Future<void> alternarLike(ItemFeed item) async {
    final fp = huellaItem(item);
    final estabaAmado = state.huellasAmadas.contains(fp);
    if (estabaAmado) {
      await quitarLike(item, fp);
    } else {
      await _darLike(item, fp);
    }
  }

  Future<void> _darLike(ItemFeed item, String fp) async {
    // Optimista: pintar el corazón y persistir el like ANTES de tocar la red.
    // En Android el bridge serializa los RPCs en un hilo, así que un RPC de
    // cover encolado detrás de una descarga larga puede tardar segundos o
    // expirar. Esperarlo aquí retrasaría el emit y el usuario vería el
    // corazón sin pintar aunque el like sí se haya dado.
    final nuevasHuellas = Set<String>.from(state.huellasAmadas)..add(fp);
    // El ISRC es el identificador que comparten TODAS las extensiones: sumarlo
    // al set hace que el corazón de un track likeado desde Deezer se refleje
    // en el mismo track desde Spotify/Amazon/etc.
    if (item.type == 'track' && item.isrc != null && item.isrc!.isNotEmpty) {
      nuevasHuellas.add(huellaIsrc(item.isrc!));
    }
    final nuevosItems = Map<String, DatosItemAmado>.from(state.todosAmados);
    nuevosItems[item.id] = DatosItemAmado(
      id: item.id,
      type: item.type,
      name: item.name,
      artists: item.artists,
      coverUrl: item.coverUrl,
      source: item.source,
      albumName: item.albumName,
      durationMs: item.durationMs,
      isrc: item.isrc,
    );

    emit(state.copiarCon(huellasAmadas: nuevasHuellas, todosAmados: nuevosItems));

    _invalidarCacheDetalle(item.id, item.type);
    await _persistirLike(item);

    // Guardar la cover es best-effort y NO bloquea el like: corre en segundo
    // plano y, si obtiene un path local, lo agrega al estado (y a la fila de
    // favoritos) cuando esté disponible.
    unawaited(_guardarCaratulaParaLike(item, fp));
  }

  void _invalidarCacheDetalle(String id, String type) {
    unawaited(_cacheDetalle.invalidarUserStats());
    switch (type) {
      case 'album':
        unawaited(_cacheDetalle.invalidarAlbum(id));
      case 'artist':
        unawaited(_cacheDetalle.invalidarArtista(id));
      case 'playlist':
        unawaited(_cacheDetalle.invalidarPlaylist(id));
      case 'track':
        // Sin id de álbum/playlist disponible; solo se invalidan los stats.
        break;
    }
  }

  /// Implementado por [AccionesLikePersistencia] (mixin en CubitLikes).
  @protected
  Future<void> _persistirLike(ItemFeed item);
}