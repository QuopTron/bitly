import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/providers/extension/extension_provider.dart';
import 'package:bitly/providers/track/track_provider.dart';
import 'package:bitly/providers/track/track_search_custom.dart';
import 'package:bitly/providers/track/track_search_helpers.dart';

export 'package:bitly/providers/track/track_provider.dart';
export 'package:bitly/providers/track/track_search_custom.dart';
export 'package:bitly/providers/track/track_search_helpers.dart';

extension TrackSearchExtension on TrackNotifier {
  Future<void> search(
    String query, {
    String? filterOverride,
  }) async {
    final requestId = ++currentRequestId;
    final currentFilter = filterOverride ?? state.selectedSearchFilter;
    final requestFilter = currentFilter == 'all' ? null : currentFilter;
    final settings = ref.read(settingsProvider);
    final extensionState = ref.read(extensionProvider);

    final resolvedProvider = resolveSearchProvider();
    final isEnabledExtensionProvider =
        resolvedProvider != null &&
        resolvedProvider.isNotEmpty &&
        extensionState.extensions.any(
          (ext) => ext.enabled && ext.id == resolvedProvider,
        );

    if (resolvedProvider != null &&
        resolvedProvider.isNotEmpty &&
        isEnabledExtensionProvider) {
      final resolvedFilter = requestFilter ?? 'track';
      Map<String, dynamic>? options;
      options = {'filter': resolvedFilter};
      await customSearch(
        resolvedProvider,
        query,
        options: options,
        selectedFilter: resolvedFilter,
      );
      return;
    }

    state = TrackState(
      isLoading: true,
      hasSearchText: state.hasSearchText,
      isShowingRecentAccess: state.isShowingRecentAccess,
      selectedSearchFilter: currentFilter ?? 'all',
    );

    try {
      final includeExtensions = settings.useExtensionProviders;

      log.i(
        'Search started: provider=metadata_extensions, query="$query", includeExtensions=$includeExtensions, filter=$requestFilter',
      );

      log.d('Calling metadata provider track search API...');
      final metadataTrackResults =
          await platformService.searchTracksWithMetadataProviders(
            query,
            limit: 20,
            includeExtensions: includeExtensions,
          );
      log.i(
        'metadata_extensions returned ${metadataTrackResults.length} tracks',
      );

      if (!isRequestValid(requestId)) {
        log.w('Search request cancelled (requestId=$requestId)');
        return;
      }

      final tracks = parseTrackResults(metadataTrackResults);
      const rawArtists = <dynamic>[];
      const rawAlbums = <dynamic>[];
      const rawPlaylists = <dynamic>[];
      final artists = parseSearchArtists(rawArtists);
      final albums = parseSearchAlbums(rawAlbums);
      final playlists = parseSearchPlaylists(rawPlaylists);

      log.i(
        'Search complete: ${tracks.length} tracks, ${artists.length} artists, ${albums.length} albums, ${playlists.length} playlists parsed successfully',
      );

      state = TrackState(
        tracks: tracks,
        searchArtists: artists,
        searchAlbums: albums,
        searchPlaylists: playlists,
        isLoading: false,
        hasSearchText: state.hasSearchText,
        isShowingRecentAccess: state.isShowingRecentAccess,
        selectedSearchFilter: currentFilter ?? 'all',
        searchSource: resolvedProvider,
      );
    } catch (e, stackTrace) {
      if (!isRequestValid(requestId)) return;
      log.e('Search failed: $e', e, stackTrace);
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
