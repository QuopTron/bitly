// ─────────────────────────────────────────────────────────────
// cache_favoritos_artistas.dart — PART de cache_favoritos.dart:
// métodos de artistas favoritos (leer lista y alternar like).
// Separado para mantener cada archivo dentro del límite de líneas.
// Se conecta con: FavoritesDao (tabla FavoriteArtists).
// Parte del flujo: Mi Espacio → Favoritos → Artistas.
// ─────────────────────────────────────────────────────────────

part of 'cache_favoritos.dart';

/// Mixin con los métodos de artistas favoritos, aplicado en CacheFavoritos.
mixin CacheFavoritosArtistas {
  /// DAO de favoritos (lo provee la clase base CacheFavoritos).
  FavoritesDao get _dao;

  /// Lista de artistas favoritos en JSON (claves camelCase + snake_case).
  Future<String> getArtistasFavoritos() async {
    final items = await _dao.getFavoriteArtists();
    final lista = items.map((e) => <String, dynamic>{
      'artistId': e.artistId, 'name': e.name,
      'imageUrl': e.imageUrl, 'imagePath': e.imagePath ?? '',
      'provider': e.provider ?? '',
      'addedAt': e.addedAt.toIso8601String(),
      'artist_id': e.artistId, 'image_url': e.imageUrl,
    }).toList();
    return jsonEncode(lista);
  }

  /// Añade o quita un artista favorito según [liked].
  Future<void> alternarArtistaFavorito({
    required String artistId,
    required String name,
    required String imageUrl,
    String? imagePath,
    bool liked = true,
  }) async {
    if (liked) {
      await _dao.addFavoriteArtist(
        artistId: artistId,
        name: name,
        imageUrl: imageUrl,
        imagePath: imagePath,
      );
    } else {
      await _dao.removeFavoriteArtist(artistId);
    }
  }
}