// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
part of 'audio_player_provider.dart';

extension AudioPlaybackExtension on AudioPlayerNotifier {
  Future<void> play({required String trackId, required String trackName, required String artistName, String? albumName, String? coverUrl, required String provider, String? isrc, String? quality, String? audioPath}) async {
    _log.i('play() called: $trackName - $artistName via $provider');
    if (trackId == state.trackId && _player != null) { await _ensurePlayer.play(); state = state.copyWith(isPlaying: true); return; }
    _playLoggedForCurrentTrack = false;
    if (albumName != null && albumName == _lastAlbumName) { _currentAlbumStreak++; } else { _currentAlbumStreak = 1; }
    _lastAlbumName = albumName;
    String? localPath;
    if (audioPath != null && await fileExists(audioPath)) localPath = audioPath;
    localPath ??= await _findLocalTrack(trackId, trackName, artistName, isrc);
    String? resolvedCoverUrl = coverUrl;
    if (localPath != null) { final cover = await _findLocalCover(localPath); if (cover != null) resolvedCoverUrl = cover; }
    _cachedVideoUrl = null; _isVideoCached = false; _videoPrefetchDone = false; _pendingVideoFetch?.ignore(); _pendingVideoFetch = null; disposeVideo(); _pollTimer?.cancel();
    state = state.copyWith(isLoading: true, isDownloading: localPath == null, downloadProgress: 0, localPath: localPath, coverUrl: resolvedCoverUrl, source: provider, albumName: albumName, isVideoReady: false, isLyricsReady: false);
    final playbackFuture = localPath != null ? _playFile(localPath) : _downloadAndPlay(trackId, trackName, artistName, provider, isrc, quality);
    state = state.copyWith(trackId: trackId, trackName: trackName, artistName: artistName);
    _log.i('localPath=$localPath -> starting ${localPath != null ? "_playFile" : "_downloadAndPlay"}');
    await playbackFuture;
    if (_pendingVideoFetch != null) await _pendingVideoFetch;
    if (_isVideoCached && _cachedVideoUrl != null && _videoController == null) await _initVideoPlayer();
  }

  Future<void> _playFile(String localPath) async {
    _log.i('Playing local file: $localPath');
    state = state.copyWith(isLoading: false, isDownloading: false, downloadProgress: 100, localPath: localPath);
    try {
      final mediaUri = Uri.file(localPath).toString();
      _log.d('Opening media: $mediaUri');
      _playbackStarted = false;
      await _ensurePlayer.open(Media(mediaUri)).timeout(const Duration(seconds: 15));
      await _ensurePlayer.play();
      state = state.copyWith(isPlaying: true);
    } on TimeoutException { _log.e('Playback open timed out for: $localPath'); state = state.copyWith(isLoading: false, isDownloading: false);
    } catch (e, st) { _log.e('Playback open/play failed for local file: $e\n$st'); state = state.copyWith(isLoading: false, isDownloading: false); }
  }

  Future<void> playLocalFile({required String filePath, required String trackName, required String artistName, String? albumName, String? coverUrl, String? source}) async {
    _pollTimer?.cancel();
    state = state.copyWith(isLoading: false, isDownloading: false, trackId: filePath, trackName: trackName, artistName: artistName, albumName: albumName, coverUrl: coverUrl, source: source, downloadProgress: 100, localPath: filePath);
    _playbackStarted = false;
    try { await _ensurePlayer.open(Media(Uri.file(filePath).toString())).timeout(const Duration(seconds: 15)); await _ensurePlayer.play(); state = state.copyWith(isPlaying: true); }
    on TimeoutException { _log.e('playLocalFile open timed out'); } catch (e, st) { _log.e('playLocalFile failed: $e\n$st'); }
  }

  Future<void> togglePlayPause() async {
    if (_player == null) return;
    if (state.isPlaying) { await _player!.pause(); state = state.copyWith(isPlaying: false); }
    else { await _player!.play(); state = state.copyWith(isPlaying: true); }
  }

  Future<void> stop() async { await _logPlayIfQualified(); _stopSyncMonitor(); _pollTimer?.cancel(); await _player?.stop(); await _videoPlayer?.stop(); state = state.copyWith(clearTrack: true); }
  Future<void> seek(Duration position) async { await _player?.seek(position); state = state.copyWith(position: position); }
  Future<void> setVolume(double volume) async { await _player?.setVolume(volume); }
  Future<void> setSpeed(double speed) async { await _player?.setRate(speed); }
}
