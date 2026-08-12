/// Domain model for a music album/EP/single.
///
/// Mirrors [Go] internal/domain/album/model.go Album struct.
class AlbumDomain {
  final String id;
  final String title;
  final String? artistId;
  final int year;
  final String? coverUrl;
  final int trackCount;
  final Map<String, dynamic>? metadata;

  const AlbumDomain({
    required this.id,
    required this.title,
    this.artistId,
    this.year = 0,
    this.coverUrl,
    this.trackCount = 0,
    this.metadata,
  });

  factory AlbumDomain.fromJson(Map<String, dynamic> json) {
    return AlbumDomain(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistId: (json['artist_id'] as String?) ?? (json['artistId'] as String?),
      year: (json['year'] as num?)?.toInt() ?? 0,
      coverUrl: (json['cover_url'] as String?) ?? (json['coverUrl'] as String?),
      trackCount:
          (json['track_count'] as num?)?.toInt() ?? (json['trackCount'] as num?)?.toInt() ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (artistId != null) 'artist_id': artistId,
    if (year > 0) 'year': year,
    if (coverUrl != null) 'cover_url': coverUrl,
    'track_count': trackCount,
    if (metadata != null) 'metadata': metadata,
  };
}

