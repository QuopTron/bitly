import 'package:equatable/equatable.dart';
import '../../../shared/models/feed_models.dart';

class SearchState extends Equatable {
  final String query;
  final String source;
  final String type;
  final List<FeedItem> results;
  final bool loading;
  final String? error;
  final bool hasSearched;
  final List<String> recentSearches;
  /// Per-source search category bubbles, from each extension's manifest.
  final Map<String, SourceSearchConfig> searchConfig;

  const SearchState({
    this.query = '',
    this.source = '',
    this.type = 'tracks',
    this.results = const [],
    this.loading = false,
    this.error,
    this.hasSearched = false,
    this.recentSearches = const [],
    this.searchConfig = const {},
  });

  SearchState copyWith({
    String? query,
    String? source,
    String? type,
    List<FeedItem>? results,
    bool? loading,
    String? error,
    bool? hasSearched,
    List<String>? recentSearches,
    Map<String, SourceSearchConfig>? searchConfig,
  }) =>
      SearchState(
        query: query ?? this.query,
        source: source ?? this.source,
        type: type ?? this.type,
        results: results ?? this.results,
        loading: loading ?? this.loading,
        error: error,
        hasSearched: hasSearched ?? this.hasSearched,
        recentSearches: recentSearches ?? this.recentSearches,
        searchConfig: searchConfig ?? this.searchConfig,
      );

  @override
  List<Object?> get props => [
        query,
        source,
        type,
        results,
        loading,
        error,
        hasSearched,
        recentSearches,
        searchConfig,
      ];
}


