import 'package:bitly/models/track.dart';
import 'package:bitly/providers/track/track_models.dart';

class TrackState {
  final List<Track> tracks;
  final bool isLoading;
  final String? error;
  final String? albumId;
  final String? albumName;
  final String? playlistName;
  final String? artistId;
  final String? artistName;
  final String? coverUrl;
  final String? headerImageUrl;
  final int? monthlyListeners;
  final List<ArtistAlbum>? artistAlbums;
  final List<Track>? artistTopTracks;
  final List<SearchArtist>? searchArtists;
  final List<SearchAlbum>? searchAlbums;
  final List<SearchPlaylist>? searchPlaylists;
  final bool hasSearchText;
  final bool isShowingRecentAccess;
  final String? searchExtensionId;
  final String? selectedSearchFilter;
  final String? searchSource;

  const TrackState({
    this.tracks = const [],
    this.isLoading = false,
    this.error,
    this.albumId,
    this.albumName,
    this.playlistName,
    this.artistId,
    this.artistName,
    this.coverUrl,
    this.headerImageUrl,
    this.monthlyListeners,
    this.artistAlbums,
    this.artistTopTracks,
    this.searchArtists,
    this.searchAlbums,
    this.searchPlaylists,
    this.hasSearchText = false,
    this.isShowingRecentAccess = false,
    this.searchExtensionId,
    this.selectedSearchFilter,
    this.searchSource,
  });

  bool get hasContent =>
      tracks.isNotEmpty ||
      artistAlbums != null ||
      (searchArtists != null && searchArtists!.isNotEmpty) ||
      (searchAlbums != null && searchAlbums!.isNotEmpty) ||
      (searchPlaylists != null && searchPlaylists!.isNotEmpty);

  TrackState copyWith({
    List<Track>? tracks,
    bool? isLoading,
    String? error,
    String? albumId,
    String? albumName,
    String? playlistName,
    String? artistId,
    String? artistName,
    String? coverUrl,
    String? headerImageUrl,
    int? monthlyListeners,
    List<ArtistAlbum>? artistAlbums,
    List<Track>? artistTopTracks,
    List<SearchArtist>? searchArtists,
    List<SearchAlbum>? searchAlbums,
    List<SearchPlaylist>? searchPlaylists,
    bool? hasSearchText,
    bool? isShowingRecentAccess,
    String? searchExtensionId,
    String? selectedSearchFilter,
    bool clearSelectedSearchFilter = false,
    String? searchSource,
    bool clearSearchSource = false,
  }) {
    return TrackState(
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      albumId: albumId ?? this.albumId,
      albumName: albumName ?? this.albumName,
      playlistName: playlistName ?? this.playlistName,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      coverUrl: coverUrl ?? this.coverUrl,
      headerImageUrl: headerImageUrl ?? this.headerImageUrl,
      monthlyListeners: monthlyListeners ?? this.monthlyListeners,
      artistAlbums: artistAlbums ?? this.artistAlbums,
      artistTopTracks: artistTopTracks ?? this.artistTopTracks,
      searchArtists: searchArtists ?? this.searchArtists,
      searchAlbums: searchAlbums ?? this.searchAlbums,
      searchPlaylists: searchPlaylists ?? this.searchPlaylists,
      hasSearchText: hasSearchText ?? this.hasSearchText,
      isShowingRecentAccess:
          isShowingRecentAccess ?? this.isShowingRecentAccess,
      searchExtensionId: searchExtensionId,
      selectedSearchFilter: clearSelectedSearchFilter
          ? null
          : (selectedSearchFilter ?? this.selectedSearchFilter),
      searchSource: clearSearchSource
          ? null
          : (searchSource ?? this.searchSource),
    );
  }
}