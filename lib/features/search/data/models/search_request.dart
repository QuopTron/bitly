
class SearchRequest {
  final String query;
  final String type;
  final List<String> sourceFilters;
  final int page;
  final int limit;

  const SearchRequest({
    required this.query,
    this.type = 'track',
    this.sourceFilters = const [],
    this.page = 1,
    this.limit = 20,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'type': type,
        'source_filters': sourceFilters,
        'page': page,
        'limit': limit,
      };

  SearchRequest copyWith({
    String? query,
    String? type,
    List<String>? sourceFilters,
    int? page,
    int? limit,
  }) =>
      SearchRequest(
        query: query ?? this.query,
        type: type ?? this.type,
        sourceFilters: sourceFilters ?? this.sourceFilters,
        page: page ?? this.page,
        limit: limit ?? this.limit,
      );
}
