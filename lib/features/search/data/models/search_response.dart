
class SearchResponse {
  final List<Map<String, dynamic>> tracks;
  final List<Map<String, dynamic>> albums;
  final List<Map<String, dynamic>> artists;
  final int totalCount;
  final bool hasMore;

  const SearchResponse({
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
    this.totalCount = 0,
    this.hasMore = false,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) =>
      SearchResponse(
        tracks: (json['tracks'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [],
        albums: (json['albums'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [],
        artists: (json['artists'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [],
        totalCount: json['total_count'] as int? ?? 0,
        hasMore: json['has_more'] as bool? ?? false,
      );
}
