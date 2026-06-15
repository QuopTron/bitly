import 'package:equatable/equatable.dart';
import '../../../domain/entities/library_track.dart';
import '../../../domain/entities/library_album.dart';
import '../../../domain/entities/library_artist.dart';

class LibraryState extends Equatable {
  final String currentView;
  final List<LibraryTrack> tracks;
  final List<LibraryAlbum> albums;
  final List<LibraryArtist> artists;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String sortBy;

  const LibraryState({
    this.currentView = 'tracks',
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.sortBy = 'name',
  });

  LibraryState copyWith({
    String? currentView,
    List<LibraryTrack>? tracks,
    List<LibraryAlbum>? albums,
    List<LibraryArtist>? artists,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? sortBy,
  }) {
    return LibraryState(
      currentView: currentView ?? this.currentView,
      tracks: tracks ?? this.tracks,
      albums: albums ?? this.albums,
      artists: artists ?? this.artists,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  List<Object?> get props => [
    currentView,
    tracks,
    albums,
    artists,
    isLoading,
    error,
    searchQuery,
    sortBy,
  ];
}
