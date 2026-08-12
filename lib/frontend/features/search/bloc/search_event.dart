import 'package:equatable/equatable.dart';
import '../../../shared/models/feed_models.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchQueryChanged extends SearchEvent {
  final String query;

  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class SearchSourceChanged extends SearchEvent {
  final String source;

  const SearchSourceChanged(this.source);

  @override
  List<Object?> get props => [source];
}

class SearchTypeChanged extends SearchEvent {
  final String type;

  const SearchTypeChanged(this.type);

  @override
  List<Object?> get props => [type];
}

class PerformSearch extends SearchEvent {
  final String query;
  final String source;
  /// Backend search type: "all" for the capped combined mix, or a category
  /// filter id (e.g. "tracks", "songs", "albums") to re-query that category.
  final String type;
  /// Max results. Ignored by the "all" mix (extension caps categories), used
  /// for per-category re-queries (e.g. 50 tracks / 20 albums).
  final int limit;

  const PerformSearch({
    this.query = '',
    this.source = '',
    this.type = 'all',
    this.limit = 25,
  });

  @override
  List<Object?> get props => [query, source, type, limit];
}

class AddRecentSearch extends SearchEvent {
  final String query;
  const AddRecentSearch(this.query);

  @override
  List<Object?> get props => [query];
}

class ClearRecentSearches extends SearchEvent {
  const ClearRecentSearches();
}

class RemoveRecentSearch extends SearchEvent {
  final String query;
  const RemoveRecentSearch(this.query);

  @override
  List<Object?> get props => [query];
}

class RecentSearchesLoaded extends SearchEvent {
  final List<String> searches;
  const RecentSearchesLoaded(this.searches);

  @override
  List<Object?> get props => [searches];
}

class ClearSearch extends SearchEvent {
  const ClearSearch();
}

class SearchConfigLoaded extends SearchEvent {
  final Map<String, SourceSearchConfig> config;
  const SearchConfigLoaded(this.config);

  @override
  List<Object?> get props => [config];
}

