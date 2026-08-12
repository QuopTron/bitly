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

  Map<String, dynamic> toJson() => {
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
      };
}

/// A search category bubble declared by a source's manifest (searchBehavior).
class SearchFilterConfig {
  final String id;
  final String label;
  final String icon;

  const SearchFilterConfig({
    required this.id,
    required this.label,
    this.icon = '',
  });

  factory SearchFilterConfig.fromJson(Map<String, dynamic> json) {
    return SearchFilterConfig(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
    );
  }
}

/// Per-source search qualifiers (category bubbles + thumbnail ratio) read from
/// the extension manifest, so the search UI renders each source the way the
/// extension intends (SpotiFLAC principle via the Bitly backend flow).
class SourceSearchConfig {
  final String source;
  final String thumbnailRatio;
  final String placeholder;
  final List<SearchFilterConfig> filters;

  const SourceSearchConfig({
    required this.source,
    this.thumbnailRatio = '',
    this.placeholder = '',
    this.filters = const [],
  });

  factory SourceSearchConfig.fromJson(Map<String, dynamic> json) {
    return SourceSearchConfig(
      source: json['source'] as String? ?? '',
      thumbnailRatio: json['thumbnailRatio'] as String? ?? '',
      placeholder: json['placeholder'] as String? ?? '',
      filters: (json['filters'] as List?)
              ?.map((e) => SearchFilterConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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

  Map<String, dynamic> toJson() => {
        'source': source,
        'display_name': displayName,
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

