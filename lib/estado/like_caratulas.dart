// ─────────────────────────────────────────────────────────────
// like_caratulas.dart — PART de cubit_like.dart. Descarga la
// carátula de un item recién likeado en segundo plano (best-effort,
// con backoff exponencial) y parchea la ruta local en el estado y en
// la fila de favoritos cuando esté disponible.
// Se conecta con: backend Go (saveCover/getCoverPathForTrack) +
// CacheFavoritos.
// Parte del flujo: like de items (persistencia de carátulas locales).
// ─────────────────────────────────────────────────────────────

part of 'cubit_like.dart';

/// Carátulas locales de items likeados (guardado en segundo plano).
mixin LikeCaratulas on AccionesLike {
  /// Guarda la carátula vía el backend y devuelve su ruta local absoluta
  /// (usable por Image.file en todas las plataformas, Android incluido).
  @override
  Future<String?> _guardarCaratula(String coverUrl) async {
    final ruta = await backend.saveCover(coverUrl);
    if (ruta != null && ruta.isNotEmpty) return ruta;
    return null;
  }

  /// Descarga la carátula de un [item] recién likeado en segundo plano y
  /// parchea la ruta local en el estado (y la fila de favoritos) cuando esté
  /// disponible. No-op si el item se des-likeó mientras guardaba.
  @override
  Future<void> _guardarCaratulaParaLike(ItemFeed item, String fp) async {
    String? rutaCaratula;
    const maxReintentos = 3;
    for (var intento = 0; intento < maxReintentos; intento++) {
      try {
        if (item.coverUrl == null || item.coverUrl!.isEmpty) break;
        if (item.type == 'track') {
          final caratulaLocal = await backend.getCoverPathForTrack(
            trackId: item.id,
            isrc: item.isrc,
            trackName: item.name,
            artistName: item.artists,
            coverUrl: item.coverUrl,
          );
          if (caratulaLocal != null && caratulaLocal.isNotEmpty) {
            rutaCaratula = caratulaLocal;
          } else {
            rutaCaratula = await _guardarCaratula(item.coverUrl!);
          }
        } else {
          rutaCaratula = await _guardarCaratula(item.coverUrl!);
        }
        if (rutaCaratula != null && rutaCaratula.isNotEmpty) break;
      } catch (_) {
        rutaCaratula = null;
      }
      // Backoff exponencial: 1s, 2s, 4s
      if (intento < maxReintentos - 1) {
        await Future<void>.delayed(Duration(seconds: 1 << intento));
      }
    }
    if (rutaCaratula == null || rutaCaratula.isEmpty) return;
    // Solo parcheamos si el item sigue likeado (pudo quitarse el like
    // mientras el RPC de cover estaba encolado).
    if (!state.huellasAmadas.contains(fp)) return;
    final actual = state.todosAmados[item.id];
    if (actual == null || actual.rutaCaratulaLocal?.isNotEmpty == true) return;
    final nuevosItems = Map<String, DatosItemAmado>.from(state.todosAmados);
    nuevosItems[item.id] = actual.copiarCon(rutaCaratulaLocal: rutaCaratula);
    emit(state.copiarCon(todosAmados: nuevosItems));
    // Persistir el coverPath en la fila de favoritos para que sobreviva al
    // reinicio.
    switch (item.type) {
      case 'track':
        unawaited(_fav.actualizarCaratulaTrack(item.id, rutaCaratula));
      case 'album':
        unawaited(_fav.actualizarCaratulaAlbum(item.id, rutaCaratula));
      case 'playlist':
        unawaited(_fav.actualizarCaratulaPlaylist(item.id, rutaCaratula));
      case 'artist':
        unawaited(_fav.actualizarImagenArtista(item.id, rutaCaratula));
    }
  }
}