// ─────────────────────────────────────────────────────────────
// cache_favoritos_playlists.dart — PART de cache_favoritos.dart:
// métodos de playlists favoritas (leer lista y alternar like).
// Separado para mantener cada archivo dentro del límite de líneas.
// Se conecta con: FavoritesDao (tabla FavoritePlaylists).
// Parte del flujo: Mi Espacio → Favoritos → Playlists.
// ─────────────────────────────────────────────────────────────

part of 'cache_favoritos.dart';

/// Mixin con los métodos de playlists favoritas, aplicado en CacheFavoritos.
/// Accede al DAO a través del getter abstracto que implementa la clase.
mixin CacheFavoritosPlaylists {
  /// DAO de favoritos (lo provee la clase base CacheFavoritos).
  FavoritesDao get _dao;

  /// Lista de playlists favoritas en JSON (claves camelCase + snake_case).
  Future<String> getPlaylistsFavoritas() async {
    final items = await _dao.getFavoritePlaylists();
    final lista = items.map((e) => <String, dynamic>{
      'playlistId': e.playlistId, 'name': e.name,
      'coverUrl': e.coverUrl ?? '', 'coverPath': e.coverPath ?? '',
      'description': e.description ?? '', 'provider': e.provider ?? '',
      'externalUrl': e.externalUrl ?? '',
      'addedAt': e.addedAt.toIso8601String(),
      'playlist_id': e.playlistId, 'cover_url': e.coverUrl ?? '',
    }).toList();
    return jsonEncode(lista);
  }

  /// Alias de lectura (nombre que usa el resto del código).
  Future<String> getPlaylistsLiked() => getPlaylistsFavoritas();

  /// Añade o quita una playlist favorita según [liked].
  Future<void> alternarPlaylistFavorita({
    required String playlistId,
    required String name,
    String? coverUrl,
    String? coverPath,
    String? provider,
    String? description,
    String? externalUrl,
    bool liked = true,
  }) async {
    if (liked) {
      await _dao.addFavoritePlaylist(FavoritePlaylistsCompanion(
        playlistId: Value(playlistId),
        name: Value(name),
        coverUrl: Value(coverUrl ?? ''),
        coverPath: Value(coverPath ?? ''),
        description: Value(description ?? ''),
        provider: Value(provider ?? ''),
        externalUrl: Value(externalUrl ?? ''),
        addedAt: Value(DateTime.now()),
      ));
    } else {
      await _dao.removeFavoritePlaylist(playlistId);
    }
  }
}