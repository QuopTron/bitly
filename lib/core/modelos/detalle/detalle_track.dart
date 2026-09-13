// ─────────────────────────────────────────────────────────────
// detalle_track.dart — Modelo de una canción dentro de un detalle
// (álbum/playlist/artista), con flags de like/descarga e ids
// cross-proveedor para resolver reproducción en cualquier fuente.
// Se conecta con: backend_go (detalle vía extensiones) + caches.
// Parte del flujo: detalle de álbum/playlist/artista.
// ─────────────────────────────────────────────────────────────

/// Canción con metadatos completos de una vista de detalle.
class TrackDetalle {
  final String trackId;
  final String name;
  final String isrc;
  final int durationMs;
  final int trackNumber;
  final String? coverUrl;
  final String? coverPath;
  final String? filePath;
  final String? artistName;
  final String? albumName;
  final String? provider;
  final String? spotifyId;
  final String? deezerId;
  final String? tidalId;
  final String? qobuzId;
  final bool isLiked;
  final bool isDownloaded;

  const TrackDetalle({
    required this.trackId,
    required this.name,
    this.durationMs = 0,
    this.trackNumber = 0,
    this.isrc = '',
    this.coverUrl,
    this.coverPath,
    this.filePath,
    this.artistName,
    this.albumName,
    this.isLiked = false,
    this.isDownloaded = false,
    this.provider,
    this.spotifyId,
    this.deezerId,
    this.tidalId,
    this.qobuzId,
  });

  factory TrackDetalle.desdeJson(Map<String, dynamic> json) => TrackDetalle(
    trackId: json['trackId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    trackNumber: (json['trackNumber'] as num?)?.toInt() ?? 0,
    isrc: json['isrc'] as String? ?? '',
    coverUrl: json['coverUrl'] as String?,
    coverPath: json['coverPath'] as String?,
    filePath: json['filePath'] as String?,
    artistName: json['artistName'] as String?,
    albumName: json['albumName'] as String?,
    isLiked: json['isLiked'] == true,
    isDownloaded: json['isDownloaded'] == true,
    provider: json['provider'] as String?,
    spotifyId: json['spotifyId'] as String?,
    deezerId: json['deezerId'] as String?,
    tidalId: json['tidalId'] as String?,
    qobuzId: json['qobuzId'] as String?,
  );
}