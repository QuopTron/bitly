class FeedItem {
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

  const FeedItem({
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
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
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
    );
  }
}

class FeedSection {
  final String source;
  final String displayName;
  final String title;
  final List<FeedItem> items;

  const FeedSection({
    required this.source,
    this.displayName = '',
    required this.title,
    required this.items,
  });

  factory FeedSection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return FeedSection(
      source: json['source'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      items: rawItems.map((e) => FeedItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
