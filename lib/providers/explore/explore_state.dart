class ExploreItem {
  final String id;
  final String uri;
  final String type;
  final String name;
  final String artists;
  final String? description;
  final String? coverUrl;
  final String? providerId;
  final String? albumId;
  final String? albumName;
  final String? releaseDate;
  final int durationMs;
  final String? isrc;

  const ExploreItem({
    required this.id,
    required this.uri,
    required this.type,
    required this.name,
    required this.artists,
    this.description,
    this.coverUrl,
    this.providerId,
    this.albumId,
    this.albumName,
    this.releaseDate,
    this.durationMs = 0,
    this.isrc,
  });

  factory ExploreItem.fromJson(Map<String, dynamic> json) {
    return ExploreItem(
      id: json['id'] as String? ?? '',
      uri: json['uri'] as String? ?? '',
      type: json['type'] as String? ?? 'track',
      name: json['name'] as String? ?? '',
      artists: json['artists'] as String? ?? '',
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
      providerId: json['provider_id'] as String?,
      albumId: json['album_id'] as String?,
      albumName: json['album_name'] as String?,
      releaseDate: json['release_date']?.toString(),
      durationMs: json['duration_ms'] as int? ?? 0,
      isrc: json['isrc'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uri': uri,
    'type': type,
    'name': name,
    'artists': artists,
    'description': description,
    'cover_url': coverUrl,
    'provider_id': providerId,
    'album_id': albumId,
    'album_name': albumName,
    'release_date': releaseDate,
    'duration_ms': durationMs,
    'isrc': isrc,
  };
}

class ExploreSection {
  final String uri;
  final String title;
  final List<ExploreItem> items;
  final bool isYTMusicQuickPicks;

  const ExploreSection({
    required this.uri,
    required this.title,
    required this.items,
    this.isYTMusicQuickPicks = false,
  });

  factory ExploreSection.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    final items = itemsList
        .map((item) => ExploreItem.fromJson(item as Map<String, dynamic>))
        .toList();
    return ExploreSection(
      uri: json['uri'] as String? ?? '',
      title: json['title'] as String? ?? '',
      items: items,
    );
  }

  Map<String, dynamic> toJson() => {
    'uri': uri,
    'title': title,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class ExploreState {
  final bool isLoading;
  final String? error;
  final String? greeting;
  final String? providerId;
  final List<ExploreSection> sections;
  final DateTime? lastFetched;

  const ExploreState({
    this.isLoading = false,
    this.error,
    this.greeting,
    this.providerId,
    this.sections = const [],
    this.lastFetched,
  });

  bool get hasContent => sections.isNotEmpty;

  ExploreState copyWith({
    bool? isLoading,
    String? error,
    String? greeting,
    String? providerId,
    bool clearProviderId = false,
    List<ExploreSection>? sections,
    DateTime? lastFetched,
  }) {
    return ExploreState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      greeting: greeting ?? this.greeting,
      providerId: clearProviderId ? null : (providerId ?? this.providerId),
      sections: sections ?? this.sections,
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }
}