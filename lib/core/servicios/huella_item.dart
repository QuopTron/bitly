// ─────────────────────────────────────────────────────────────
// huella_item.dart — Genera "huellas" (fingerprints) canónicas de
// items para comparar tracks/álbumes/artistas/playlists entre
// fuentes (Deezer vs Spotify vs Amazon...) normalizando nombres y
// artistas. La huella ISRC permite cruzar la MISMA grabación entre
// todas las extensiones.
// Se conecta con: modelos (ItemFeed) + caches (likes/descargas).
// Parte del flujo: like, descargas, deduplicación de items.
// ─────────────────────────────────────────────────────────────

import '../modelos/item_feed.dart';

String _normalizar(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> extraerArtistas(String? artists) {
  if (artists == null || artists.isEmpty) return [];
  final normalizado = artists
      .replaceAll(RegExp(r'\s*feat\.?\s*', caseSensitive: false), ',')
      .replaceAll(RegExp(r'\s*ft\.?\s*', caseSensitive: false), ',')
      .replaceAll(RegExp(r'\s*&\s*'), ',')
      .replaceAll(RegExp(r'\s*,\s*'), ',')
      .replaceAll(RegExp(r'\s+y\s+', caseSensitive: false), ',')
      .replaceAll(RegExp(r'\s*,\s*'), ',');
  return normalizado
      .split(',')
      .map((a) => _normalizar(a))
      .where((a) => a.isNotEmpty)
      .toList();
}

String huellaTrack(ItemFeed item) {
  final nombre = _normalizar(item.name);
  final artistas = extraerArtistas(item.artists).join('+');
  return 'track:$nombre|$artistas';
}

String huellaAlbum(ItemFeed item) {
  final nombre = _normalizar(item.name);
  final artistas = extraerArtistas(item.artists).join('+');
  return 'album:$nombre|$artistas';
}

String huellaArtista(ItemFeed item) {
  final nombre = _normalizar(item.name);
  return 'artist:$nombre';
}

String huellaPlaylist(ItemFeed item) {
  final nombre = _normalizar(item.name);
  final src = item.source ?? '';
  return 'playlist:$src|${item.id}|$nombre';
}

String huellaItem(ItemFeed item) {
  switch (item.type) {
    case 'track':
      return huellaTrack(item);
    case 'album':
      return huellaAlbum(item);
    case 'artist':
      return huellaArtista(item);
    case 'playlist':
      return huellaPlaylist(item);
    default:
      return '${item.type}:${_normalizar(item.name)}';
  }
}

String huellaDesdeNombre(String name, String artists) {
  final n = _normalizar(name);
  final a = extraerArtistas(artists).join('+');
  return 'track:$n|$a';
}

/// Huella canónica por ISRC (el identificador que comparten TODAS las
/// extensiones para la misma grabación). Permite que el corazón de un track
/// likeado desde Deezer se refleje en el mismo track desde Spotify/Amazon/etc,
/// incluso si el título/artista vienen escritos distinto.
String huellaIsrc(String isrc) => 'isrc:${isrc.trim().toUpperCase()}';