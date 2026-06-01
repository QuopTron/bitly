// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

part of 'audio_player_provider.dart';

extension AudioVideoSyncExtension on AudioPlayerNotifier {
  void _startSyncMonitor() {
    if (_syncMonitorActive) {
      _log.i('Sync monitor already active');
      return;
    }

    _syncMonitorActive = true;
    _log.i('Starting audio-video sync monitor');

    _audioPositionSubscription = _player?.stream.position.listen((audioPos) {
      if (_videoPlayer == null || !state.isAudioVideoSynced) return;

      _videoPlayer!.stream.position.first.then((videoPos) {
        final diff = (audioPos - videoPos).abs();

        if (diff > const Duration(milliseconds: 200)) {
          _log.w('AV sync drift detected: ${diff.inMilliseconds}ms, resyncing...');
          _videoPlayer!.seek(audioPos);
          state = state.copyWith(audioVideoOffset: diff);
        }
      });
    });

    _videoPositionSubscription = _videoPlayer?.stream.buffering.listen((isBuffering) {
      if (isBuffering) {
        _log.i('Video buffering, pausing audio temporarily');
        _player?.pause();
      } else {
        _log.i('Video buffer ready, resuming audio');
        _player?.play();
      }
    });
  }

  void _stopSyncMonitor() {
    _syncMonitorActive = false;
    _audioPositionSubscription?.cancel();
    _videoPositionSubscription?.cancel();
    _audioPositionSubscription = null;
    _videoPositionSubscription = null;
    _log.i('Sync monitor stopped');
  }

  void pauseVideo() {
    _videoPlayer?.pause();
    _stopSyncMonitor();
    state = state.copyWith(isAudioVideoSynced: false);
  }

  Future<void> resyncAudioVideo() async {
    if (_videoPlayer == null || _player == null) {
      _log.w('Cannot resync: players not initialized');
      return;
    }

    try {
      _log.i('Manual audio-video resync requested');

      final audioPos = _player!.state.position;

      await _videoPlayer!.seek(audioPos);

      _stopSyncMonitor();
      _startSyncMonitor();

      state = state.copyWith(
        isAudioVideoSynced: true,
        audioVideoOffset: Duration.zero,
      );

      _log.i('Audio-video resynced to: $audioPos');
    } catch (e) {
      _log.e('Resync failed: $e');
      state = state.copyWith(isAudioVideoSynced: false);
      rethrow;
    }
  }

  void handleVideoEnded() {
    _log.i('Video playback ended');
    _stopSyncMonitor();
    _videoReady = false;
    state = state.copyWith(isAudioVideoSynced: false);
  }

  void handleVideoError(Object error) {
    _log.e('Video playback error: $error');
    disposeVideo();
  }
}
