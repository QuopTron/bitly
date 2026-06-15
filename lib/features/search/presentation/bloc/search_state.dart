import 'package:equatable/equatable.dart';

class SearchState extends Equatable {
  final String query;
  final String type;
  final List<Map<String, dynamic>> tracks;
  final List<Map<String, dynamic>> albums;
  final List<Map<String, dynamic>> artists;
  final bool isLoading;
  final String? error;
  final List<String> recentSearches;
  final bool hasMore;
  final int currentPage;

  const SearchState({
    this.query = '',
    this.type = 'track',
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
    this.isLoading = false,
    this.error,
    this.recentSearches = const [],
    this.hasMore = false,
    this.currentPage = 1,
  });

  SearchState copyWith({
    String? query,
    String? type,
    List<Map<String, dynamic>>? tracks,
    List<Map<String, dynamic>>? albums,
    List<Map<String, dynamic>>? artists,
    bool? isLoading,
    String? error,
    List<String>? recentSearches,
    bool? hasMore,
    int? currentPage,
  }) =>
      SearchState(
        query: query ?? this.query,
        type: type ?? this.type,
        tracks: tracks ?? this.tracks,
        albums: albums ?? this.albums,
        artists: artists ?? this.artists,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        recentSearches: recentSearches ?? this.recentSearches,
        hasMore: hasMore ?? this.hasMore,
        currentPage: currentPage ?? this.currentPage,
      );

  @override
  List<Object?> get props => [
        query,
        type,
        tracks,
        albums,
        artists,
        isLoading,
        error,
        recentSearches,
        hasMore,
        currentPage,
      ];
}
