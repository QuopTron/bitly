// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

part of 'audio_player_provider.dart';

extension AudioVideoExtension on AudioPlayerNotifier {
  Future<void> startVideo(String trackName, String artistName) async {
    if (_videoController != null && _videoReady) {
      return;
    }

    if (_isVideoCached && _cachedVideoUrl != null) {
      try {
        _log.i('Initializing video player with cached URL (source: $_currentVideoSource)');
        await _initVideoPlayer();
        return;
      } catch (e) {
        _log.e('Video initialization failed, will try prefetch: $e');
      }
    }

    if (state.isVideoReady) {
      _log.w('startVideo: isVideoReady=true but no cached URL, attempting prefetch');
      await prefetchVideo(trackName, artistName);
      if (_isVideoCached && _cachedVideoUrl != null) {
        await _initVideoPlayer();
      }
      return;
    }

    if (_pendingVideoFetch != null) {
      _log.i('Waiting for pending video fetch...');
      await _pendingVideoFetch;
      if (_isVideoCached && _cachedVideoUrl != null) {
        await _initVideoPlayer();
      }
      return;
    }

    _log.i('No cached video, starting prefetch process');
    await prefetchVideo(trackName, artistName);

    if (!_isVideoCached || _cachedVideoUrl == null) {
      _log.w('Video prefetch completed but no video available');
      throw Exception('No video available from any source');
    }
  }

  Future<void> _initVideoPlayer() async {
    if (_videoController != null) return;
    final url = _cachedVideoUrl;
    if (url == null) return;

    await _videoPlayer?.dispose();
    _videoPlayer = Player();

    if (_videoPlayer!.platform is NativePlayer) {
      try {
        (_videoPlayer!.platform as NativePlayer).setProperty('audio', 'no');
      } catch (e) {
        _log.w('Failed to set player properties: $e');
      }
    }

    _videoController = VideoController(_videoPlayer!);
    _log.i('Opening video stream: $url');
    try {
      await _videoPlayer!.open(Media(url)).timeout(const Duration(seconds: 60));
      _videoReady = true;
      state = state.copyWith(
        videoController: _videoController,
        isVideoReady: true,
        isAudioVideoSynced: false,
      );
      _log.i('Video stream opened successfully');
      if (ref.read(viewModeProvider) == ViewMode.cover) {
        ref.read(viewModeProvider.notifier).toggle();
      }
    } catch (e) {
      _log.e('Failed to open video stream: $e');
      _videoPlayer?.dispose();
      _videoPlayer = null;
      _videoController = null;
      _isVideoCached = false;
      _cachedVideoUrl = null;
      state = state.copyWith(
        isVideoReady: false,
        isAudioVideoSynced: false,
        audioVideoOffset: Duration.zero,
      );
      rethrow;
    }
  }

  Future<void> playVideo([Duration? seekPosition]) async {
    if (_videoPlayer == null) {
      _log.w('playVideo called but video player is null');
      return;
    }

    try {
      if (seekPosition != null && seekPosition > Duration.zero) {
        await _videoPlayer!.seek(seekPosition);
        _log.i('Video seeked to: $seekPosition');
      }

      await _videoPlayer!.play();
      _log.i('Video playback started');

      _startSyncMonitor();
      state = state.copyWith(isAudioVideoSynced: true, audioVideoOffset: Duration.zero);
    } catch (e) {
      _log.e('playVideo failed: $e');
      state = state.copyWith(isAudioVideoSynced: false);
      rethrow;
    }
  }

  Future<void> stopVideo() async {
    try {
      await _videoPlayer?.stop();
    } catch (e) {}
  }

  void disposeVideo() {
    _stopSyncMonitor();
    _videoPlayer?.dispose();
    _videoPlayer = null;
    _videoController = null;
    state = state.copyWith(
      videoController: null,
      isVideoReady: false,
      isAudioVideoSynced: false,
      audioVideoOffset: Duration.zero,
    );
  }
}
