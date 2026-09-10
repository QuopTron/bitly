// ─────────────────────────────────────────────────────────────
// dominio_playlist.dart — Modelos de dominio de playlists del
// usuario (colecciones) y sus tracks.
// Refleja el struct Playlist del backend Go
// (go_backend/internal/domain/playlist/model.go).
// Se conecta con: backend_go (RPC de playlists) + drift local.
// Parte del flujo: Mi Espacio → playlists.
// ─────────────────────────────────────────────────────────────

/// Colección (playlist) creada por el usuario.
class PlaylistDominio {
  final String id;
  final String? userId;
  final String name;
  final String description;
  final String? coverUrl;
  final int trackCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PlaylistDominio({
    required this.id,
    this.userId,
    required this.name,
    this.description = '',
    this.coverUrl,
    this.trackCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory PlaylistDominio.desdeJson(Map<String, dynamic> json) {
    return PlaylistDominio(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coverUrl: (json['cover_url'] as String?) ?? (json['coverPath'] as String?),
      trackCount: (json['track_count'] as num?)?.toInt() ?? (json['itemCount'] as num?)?.toInt() ?? 0,
      createdAt: _parsearFecha(json['created_at'] ?? json['createdAt']),
      updatedAt: _parsearFecha(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> aJson() => {
    'id': id,
    if (userId != null) 'user_id': userId,
    'name': name,
    'description': description,
    if (coverUrl != null) 'cover_url': coverUrl,
    'track_count': trackCount,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  static DateTime? _parsearFecha(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

/// Track dentro de una playlist del usuario.
class PlaylistTrackDominio {
  final String playlistId;
  final String trackId;
  final int position;
  final DateTime? addedAt;

  const PlaylistTrackDominio({
    required this.playlistId,
    required this.trackId,
    this.position = 0,
    this.addedAt,
  });

  factory PlaylistTrackDominio.desdeJson(Map<String, dynamic> json) {
    return PlaylistTrackDominio(
      playlistId: json['playlist_id'] as String? ?? '',
      trackId: json['track_id'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      addedAt: PlaylistDominio._parsearFecha(json['added_at']),
    );
  }

  Map<String, dynamic> aJson() => {
    'playlist_id': playlistId,
    'track_id': trackId,
    'position': position,
    if (addedAt != null) 'added_at': addedAt!.toIso8601String(),
  };
}