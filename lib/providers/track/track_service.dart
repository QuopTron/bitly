import 'package:bitly/utils/string_utils.dart';
import 'package:bitly/providers/extension/extension_provider.dart';
import 'package:bitly/providers/track/track_provider.dart';

export 'package:bitly/providers/track/track_provider.dart';

extension TrackServiceExtension on TrackNotifier {
  Future<void> fetchFromUrl(String url, {bool useDeezerFallback = true}) async {
    final requestId = ++currentRequestId;
    state = TrackState(isLoading: true, hasSearchText: state.hasSearchText);
    try {
      var extensionHandler = await platformService.findURLHandler(url);
      if (extensionHandler == null) {
        final extensionState = ref.read(extensionProvider);
        if (!extensionState.isInitialized && extensionState.isLoading) {
          log.i('Extension URL handlers not ready, waiting for initialization...');
          await ref.read(extensionProvider.notifier).waitForInitialization(timeout: extensionInitRetryTimeout);
          if (!isRequestValid(requestId)) return;
          extensionHandler = await platformService.findURLHandler(url);
        }
      }
      if (extensionHandler == null) {
        state = TrackState(isLoading: false, error: 'url_not_recognized', hasSearchText: state.hasSearchText);
        return;
      }
      log.i('Found extension URL handler: $extensionHandler for URL: $url');
      Map<String, dynamic>? result;
      for (int attempt = 1; attempt <= 3; attempt++) {
        result = await platformService.handleURLWithExtension(url);
        if (!isRequestValid(requestId)) return;
        if (result != null && result['type'] == 'track' && result['track'] != null) {
          final name = (result['track'] as Map<String, dynamic>)['name']?.toString() ?? '';
          if (name.isNotEmpty) break;
        } else if (result != null && (result['type'] == 'album' || result['type'] == 'playlist' || result['type'] == 'artist')) {
          break;
        }
        if (attempt < 3) await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (result != null) {
        final type = result['type'] as String?;
        final extensionId = result['extension_id'] as String?;
        if (type == 'track' && result['track'] != null) {
          final track = parseSearchTrack(result['track'] as Map<String, dynamic>, source: extensionId);
          if (track.name.isEmpty) {
            state = TrackState(isLoading: false, error: 'Failed to load track metadata from extension');
            return;
          }
          state = TrackState(tracks: [track], isLoading: false, coverUrl: track.coverUrl, searchExtensionId: extensionId);
          return;
        } else if ((type == 'album' || type == 'playlist') && result['tracks'] != null) {
          final tracks = (result['tracks'] as List<dynamic>).map((t) => parseSearchTrack(t as Map<String, dynamic>, source: extensionId)).toList();
          state = TrackState(tracks: tracks, isLoading: false, albumId: (result['album'] as Map<String, dynamic>?)?['id'] as String?, albumName: result['name'] as String? ?? (result['album'] as Map<String, dynamic>?)?['name'] as String?, playlistName: type == 'playlist' ? result['name'] as String? : null, coverUrl: normalizeCoverReference(result['cover_url']?.toString()), searchExtensionId: extensionId);
          return;
        } else if (type == 'artist' && result['artist'] != null) {
          final artistData = result['artist'] as Map<String, dynamic>;
          final albums = (artistData['albums'] as List<dynamic>? ?? []).map((a) => parseArtistAlbum(a as Map<String, dynamic>)).toList();
          final topTracks = (artistData['top_tracks'] as List<dynamic>? ?? []).map((t) => parseSearchTrack(t as Map<String, dynamic>, source: extensionId)).toList();
          state = TrackState(tracks: [], isLoading: false, artistId: artistData['id'] as String?, artistName: artistData['name'] as String?, coverUrl: normalizeRemoteHttpUrl((artistData['image_url'] ?? artistData['images'])?.toString()), headerImageUrl: normalizeRemoteHttpUrl(artistData['header_image']?.toString()), monthlyListeners: artistData['listeners'] as int?, artistAlbums: albums, artistTopTracks: topTracks.isNotEmpty ? topTracks : null, searchExtensionId: extensionId);
          return;
        }
      }
      state = TrackState(isLoading: false, error: 'url_not_recognized', hasSearchText: state.hasSearchText);
    } catch (e) {
      if (!isRequestValid(requestId)) return;
      state = TrackState(isLoading: false, error: e.toString(), hasSearchText: state.hasSearchText);
    }
  }

}
