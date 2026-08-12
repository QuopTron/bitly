/// Domain model for a user-created playlist collection.
///
/// Mirrors [Go] internal/domain/playlist/model.go Playlist struct.
class PlaylistDomain {
  final String id;
  final String? userId;
  final String name;
  final String description;
  final String? coverUrl;
  final int trackCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PlaylistDomain({
    required this.id,
    this.userId,
    required this.name,
    this.description = '',
    this.coverUrl,
    this.trackCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory PlaylistDomain.fromJson(Map<String, dynamic> json) {
    return PlaylistDomain(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coverUrl: (json['cover_url'] as String?) ?? (json['coverPath'] as String?),
      trackCount: (json['track_count'] as num?)?.toInt() ?? (json['itemCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userId != null) 'user_id': userId,
    'name': name,
    'description': description,
    if (coverUrl != null) 'cover_url': coverUrl,
    'track_count': trackCount,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

/// Domain model for a track inside a playlist.
///
/// Mirrors [Go] internal/domain/playlist/model.go PlaylistTrack struct.
class PlaylistTrackDomain {
  final String playlistId;
  final String trackId;
  final int position;
  final DateTime? addedAt;

  const PlaylistTrackDomain({
    required this.playlistId,
    required this.trackId,
    this.position = 0,
    this.addedAt,
  });

  factory PlaylistTrackDomain.fromJson(Map<String, dynamic> json) {
    return PlaylistTrackDomain(
      playlistId: json['playlist_id'] as String? ?? '',
      trackId: json['track_id'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      addedAt: PlaylistDomain._parseDateTime(json['added_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'playlist_id': playlistId,
    'track_id': trackId,
    'position': position,
    if (addedAt != null) 'added_at': addedAt!.toIso8601String(),
  };
}

