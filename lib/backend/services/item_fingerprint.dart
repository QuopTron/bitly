import '../../frontend/shared/models/feed_models.dart';

String _normalize(String s) {
  return s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\w\s]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
}

List<String> extractArtists(String? artists) {
  if (artists == null || artists.isEmpty) return [];
  final normalized = artists
    .replaceAll(RegExp(r'\s*feat\.?\s*', caseSensitive: false), ',')
    .replaceAll(RegExp(r'\s*ft\.?\s*', caseSensitive: false), ',')
    .replaceAll(RegExp(r'\s*&\s*'), ',')
    .replaceAll(RegExp(r'\s*,\s*'), ',')
    .replaceAll(RegExp(r'\s+y\s+', caseSensitive: false), ',')
    .replaceAll(RegExp(r'\s*,\s*'), ',');
  return normalized
    .split(',')
    .map((a) => _normalize(a))
    .where((a) => a.isNotEmpty)
    .toList();
}

String fingerprintTrack(FeedItem item) {
  final name = _normalize(item.name);
  final artists = extractArtists(item.artists).join('+');
  return 'track:$name|$artists';
}

String fingerprintAlbum(FeedItem item) {
  final name = _normalize(item.name);
  final artists = extractArtists(item.artists).join('+');
  return 'album:$name|$artists';
}

String fingerprintArtist(FeedItem item) {
  final name = _normalize(item.name);
  return 'artist:$name';
}

String fingerprintPlaylist(FeedItem item) {
  final name = _normalize(item.name);
  final src = item.source ?? '';
  return 'playlist:$src|${item.id}|$name';
}

String fingerprintItem(FeedItem item) {
  switch (item.type) {
    case 'track':
      return fingerprintTrack(item);
    case 'album':
      return fingerprintAlbum(item);
    case 'artist':
      return fingerprintArtist(item);
    case 'playlist':
      return fingerprintPlaylist(item);
    default:
      return '${item.type}:${_normalize(item.name)}';
  }
}

String fingerprintFromName(String name, String artists) {
  final n = _normalize(name);
  final a = extractArtists(artists).join('+');
  return 'track:$n|$a';
}

/// Fingerprint canónico por ISRC (el identificador que comparten TODAS las
/// extensiones para la misma grabación). Permite que el corazón de un track
/// likeado desde Deezer se refleje en el mismo track desde Spotify/Amazon/etc,
/// incluso si el título/artista vienen escritos distinto.
String fingerprintIsrc(String isrc) => 'isrc:${isrc.trim().toUpperCase()}';


