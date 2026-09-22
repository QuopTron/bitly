// ─────────────────────────────────────────────────────────────
// huella_item.dart — Genera "huellas" (fingerprints) canónicas de
// items para comparar tracks/álbumes/artistas/playlists entre
// fuentes (Deezer vs Spotify vs Amazon...) normalizando nombres y
// artistas. La huella ISRC permite cruzar la MISMA grabación entre
// todas las extensiones.
// Se conecta con: modelos (ItemFeed) + caches (likes/descargas).
// Parte del flujo: like, descargas, deduplicación de items.
// ─────────────────────────────────────────────────────────────

import '../../modelos/feed/item_feed.dart';

// Las expresiones se compilan UNA vez, no en cada llamada.
//
// Por qué: estas funciones corren en el `build()` de cada tarjeta (la huella
// del like y la de la carátula) y antes construían ~8 `RegExp` por llamada,
// cada uno compilando su patrón. Con una biblioteca grande y una lista en
// pantalla eso solo ya consumía el presupuesto de frame: era el motivo de que
// la app fuera a tirones en celular, TV y PC por igual.
final RegExp _reNoPalabra = RegExp(r'[^\w\s]');
final RegExp _reEspacios = RegExp(r'\s+');
final RegExp _reFeat = RegExp(r'\s*feat\.?\s*', caseSensitive: false);
final RegExp _reFt = RegExp(r'\s*ft\.?\s*', caseSensitive: false);
final RegExp _reAmpersand = RegExp(r'\s*&\s*');
final RegExp _reComa = RegExp(r'\s*,\s*');
final RegExp _reY = RegExp(r'\s+y\s+', caseSensitive: false);

String _normalizar(String s) {
  return s
      .toLowerCase()
      .replaceAll(_reNoPalabra, '')
      .replaceAll(_reEspacios, ' ')
      .trim();
}

List<String> extraerArtistas(String? artists) {
  if (artists == null || artists.isEmpty) return [];
  final normalizado = artists
      .replaceAll(_reFeat, ',')
      .replaceAll(_reFt, ',')
      .replaceAll(_reAmpersand, ',')
      .replaceAll(_reComa, ',')
      .replaceAll(_reY, ',')
      .replaceAll(_reComa, ',');
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
