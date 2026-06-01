// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

part of 'audio_player_provider.dart';

extension AudioCacheExtension on AudioPlayerNotifier {
  Future<void> prefetchVideo(String trackName, String artistName) async {
    if (state.isVideoReady) {
      _log.i('Video for $trackName - $artistName already ready, skipping prefetch');
      return;
    }
    if (_pendingVideoFetch != null) {
      final existing = _pendingVideoFetch;
      _log.i('Video for $trackName - $artistName already loading, waiting');
      await existing;
      return;
    }

    _pendingVideoFetch = (() async {
      _currentVideoSource = 'None';
      _log.i('Starting video prefetch for: $trackName - $artistName');

      final sortedSources = [..._videoSources]..sort((a, b) => a.priority.compareTo(b.priority));

      for (final source in sortedSources) {
        try {
          _log.i('Trying ${source.name} (priority ${source.priority}) for video...');

          final videoUrl = await source.fetchFunction(trackName, artistName);

          if (videoUrl != null && videoUrl.isNotEmpty) {
            _cachedVideoUrl = videoUrl;
            _isVideoCached = true;
            _currentVideoSource = source.name;

            _log.i('Video found via ${source.name}: $videoUrl');
            state = state.copyWith(isVideoReady: true);

            if (source.name == 'YouTube') {
              _cacheVideoLocally(videoUrl, trackName, artistName);
            }

            return;
          }
        } catch (e) {
          _log.w('${source.name} video fetch failed: $e');
          continue;
        }
      }

      _log.e('All video sources failed for: $trackName - $artistName');
      _isVideoCached = false;
      _cachedVideoUrl = null;
      _currentVideoSource = 'None';
      state = state.copyWith(isVideoReady: false);
    })();

    await _pendingVideoFetch;
    _pendingVideoFetch = null;
  }

  Future<String?> _checkLocalVideoCache(String trackName, String artistName) async {
    try {
      final cacheManager = VideoCacheManager();
      final cachedPath = await cacheManager.getCachedVideo(trackName, artistName);

      if (cachedPath != null) {
        _log.i('Found cached video via VideoCacheManager: $cachedPath');
        return cachedPath;
      }
      return null;
    } catch (e) {
      _log.w('Local cache check failed: $e');
      return null;
    }
  }

  Future<String?> _fetchYouTubeVideo(String trackName, String artistName) async {
    try {
      _log.i('Searching YouTube video for: $trackName - $artistName');
      final streamUrl = await PlatformBridge.searchYouTubeVideo(
        trackName: trackName,
        artistName: artistName,
      ).timeout(const Duration(seconds: 30));

      if (streamUrl.isNotEmpty && streamUrl.startsWith('http')) {
        _log.i('YouTube video found: $streamUrl');
        return streamUrl;
      }
      return null;
    } catch (e) {
      _log.w('YouTube search failed: $e');
      return null;
    }
  }

  Future<String?> _fetchTidalVideo(String trackName, String artistName) async {
    try {
      _log.i('Searching Tidal video for: $trackName - $artistName');
      final result = await PlatformBridge.searchTidalVideo(
        trackName: trackName,
        artistName: artistName,
      ).timeout(const Duration(seconds: 20));

      if (result.isNotEmpty) {
        _log.i('Tidal video found: $result');
        return result;
      }
      return null;
    } catch (e) {
      _log.w('Tidal video search failed: $e');
      return null;
    }
  }

  Future<String?> _fetchQobuzVideo(String trackName, String artistName) async {
    try {
      _log.i('Searching Qobuz video for: $trackName - $artistName');
      final result = await PlatformBridge.searchQobuzVideo(
        trackName: trackName,
        artistName: artistName,
      ).timeout(const Duration(seconds: 20));

      if (result.isNotEmpty) {
        _log.i('Qobuz video found: $result');
        return result;
      }
      return null;
    } catch (e) {
      _log.w('Qobuz video search failed: $e');
      return null;
    }
  }

  Future<void> _cacheVideoLocally(String videoUrl, String trackName, String artistName) async {
    try {
      _log.i('Caching video to local storage: $trackName - $artistName');

      final cacheManager = VideoCacheManager();
      await cacheManager.cacheVideo(videoUrl, trackName, artistName);

      _log.i('Video cached successfully via VideoCacheManager');
    } catch (e) {
      _log.e('Video caching failed: $e');
    }
  }
}
