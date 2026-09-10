// ─────────────────────────────────────────────────────────────
// item_feed.dart — Modelo de un ítem del feed/búsqueda (canción,
// álbum, playlist o artista) tal como lo devuelve el backend Go.
// Se conecta con: backend_go (respuestas RPC de feed/búsqueda/detalle).
// Parte del flujo: feed, búsqueda, detalle, reproducción.
// ─────────────────────────────────────────────────────────────

/// Ítem genérico del feed — el formato en que viaja entre Go y Flutter.
class ItemFeed {
  final String id;
  final String type;
  final String name;
  final String? artists;
  final String? coverUrl;
  final String? source;
  final String? albumId;
  final String? albumName;
  final int? durationMs;
  final String? releaseDate;
  final int? totalTracks;
  final String? owner;
  final String? isrc;
  /// Ids cross-proveedor que llevan los tracks de detalle (álbum/artista/
  /// playlist) para que la reproducción resuelva en CUALQUIER extensión vía
  /// CheckAvailability en vez de una búsqueda lenta por nombre.
  final String? spotifyId;
  final String? deezerId;
  final String? tidalId;
  final String? qobuzId;

  const ItemFeed({
    required this.id,
    required this.type,
    required this.name,
    this.artists,
    this.coverUrl,
    this.source,
    this.albumId,
    this.albumName,
    this.durationMs,
    this.releaseDate,
    this.totalTracks,
    this.owner,
    this.isrc,
    this.spotifyId,
    this.deezerId,
    this.tidalId,
    this.qobuzId,
  });

  factory ItemFeed.desdeJson(Map<String, dynamic> json) {
    return ItemFeed(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'track',
      name: json['name'] as String? ?? '',
      artists: json['artists'] as String?,
      coverUrl: json['cover_url'] as String?,
      source: json['source'] as String?,
      albumId: json['album_id'] as String?,
      albumName: json['album_name'] as String?,
      durationMs: json['duration_ms'] as int?,
      releaseDate: json['release_date'] as String?,
      totalTracks: json['total_tracks'] as int?,
      owner: json['owner'] as String?,
      isrc: json['isrc'] as String?,
      spotifyId: json['spotify_id'] as String?,
      deezerId: json['deezer_id'] as String?,
      tidalId: json['tidal_id'] as String?,
      qobuzId: json['qobuz_id'] as String?,
    );
  }

  Map<String, dynamic> aJson() => {
        'id': id,
        'type': type,
        'name': name,
        'artists': artists,
        'cover_url': coverUrl,
        'source': source,
        'album_id': albumId,
        'album_name': albumName,
        'duration_ms': durationMs,
        'release_date': releaseDate,
        'total_tracks': totalTracks,
        'owner': owner,
        'isrc': isrc,
        'spotify_id': spotifyId,
        'deezer_id': deezerId,
        'tidal_id': tidalId,
        'qobuz_id': qobuzId,
      };
}