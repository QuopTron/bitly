import 'package:bitly/models/track.dart';
import 'package:bitly/providers/track/track_models.dart';
import 'package:bitly/providers/track/track_provider.dart';

extension TrackSearchCustomExtension on TrackNotifier {
  Future<void> customSearch(
    String extensionId,
    String query, {
    Map<String, dynamic>? options,
    String? selectedFilter,
  }) async {
    final requestId = ++currentRequestId;
    final currentFilter = selectedFilter ?? state.selectedSearchFilter;

    state = TrackState(
      isLoading: true,
      hasSearchText: state.hasSearchText,
      isShowingRecentAccess: state.isShowingRecentAccess,
      selectedSearchFilter: currentFilter ?? 'all',
    );

    try {
      log.i('Custom search started: extension=$extensionId, query="$query"');

      final results = await platformService.customSearchWithExtension(
        extensionId,
        query,
        options: options,
        cancelPrevious: true,
      );

      if (!isRequestValid(requestId)) {
        log.w('Custom search request cancelled (requestId=$requestId)');
        return;
      }

      log.i('Custom search returned ${results.length} items');
      log.d('First item sample: ${results.isNotEmpty ? results[0] : 'no items'}');

      final tracks = <Track>[];
      final artists = <SearchArtist>[];
      final albums = <SearchAlbum>[];
      final playlists = <SearchPlaylist>[];

      for (int i = 0; i < results.length; i++) {
        final item = results[i];
        try {
          final itemType = item['item_type']?.toString().toLowerCase() ?? '';
          log.d('Item $i type: $itemType, name: ${item['name']?.toString() ?? 'unknown'}');

          switch (itemType) {
            case 'artist':
              artists.add(SearchArtist.fromJson(item));
              break;
            case 'album':
              albums.add(SearchAlbum.fromJson(item));
              break;
            case 'playlist':
              playlists.add(SearchPlaylist.fromJson(item));
              break;
            case 'track':
            default:
              tracks.add(parseSearchTrack(item, source: extensionId));
              break;
          }
        } catch (e) {
          log.e('Failed to parse custom search item[$i]: $e', e);
        }
      }

      log.i(
        'Custom search complete: ${tracks.length} tracks, ${artists.length} artists, ${albums.length} albums, ${playlists.length} playlists parsed (source=$extensionId)',
      );

      final filteredArtists = currentFilter == 'artist' ? artists : (currentFilter == null || currentFilter == 'all' ? artists : <SearchArtist>[]);
      final filteredAlbums = currentFilter == 'album' ? albums : (currentFilter == null || currentFilter == 'all' ? albums : <SearchAlbum>[]);
      final filteredPlaylists = currentFilter == 'playlist' ? playlists : (currentFilter == null || currentFilter == 'all' ? playlists : <SearchPlaylist>[]);

      state = TrackState(
        tracks: tracks,
        searchArtists: filteredArtists,
        searchAlbums: filteredAlbums,
        searchPlaylists: filteredPlaylists,
        isLoading: false,
        hasSearchText: state.hasSearchText,
        isShowingRecentAccess: state.isShowingRecentAccess,
        searchExtensionId: extensionId,
        selectedSearchFilter: currentFilter,
      );
    } catch (e, stackTrace) {
      if (!isRequestValid(requestId)) return;
      log.e('Custom search failed: $e', e, stackTrace);
      state = TrackState(
        isLoading: false,
        error: e.toString(),
        hasSearchText: state.hasSearchText,
        isShowingRecentAccess: state.isShowingRecentAccess,
        selectedSearchFilter: currentFilter,
      );
    }
  }
}
