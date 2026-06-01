library audio_player_provider;

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/download/download_queue_provider.dart' show DownloadHistoryItem;
import 'package:bitly/providers/playback/playback_queue_provider.dart';
import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/providers/stats/stats_provider.dart';
import 'package:bitly/providers/view_mode/view_mode_provider.dart';
import 'package:bitly/services/cache/video_cache_manager.dart';
import 'package:bitly/services/downloads/download_request_payload.dart';
import 'package:bitly/services/history/history_database.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/services/statistics/stats_database.dart';
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/utils/logger.dart';
import 'package:media_kit/media_kit.dart' show Media, NativePlayer, Player;
import 'package:media_kit_video/media_kit_video.dart' show VideoController;
import 'package:bitly/providers/audio/audio_player_state.dart';

export 'package:bitly/providers/audio/audio_player_state.dart';

part 'audio_playback.dart';
part 'audio_video.dart';
part 'audio_video_sync.dart';
part 'audio_queue.dart';
part 'audio_service.dart';
part 'audio_cache.dart';

final _log = AppLogger('AudioPlayer');

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  Player? _player;
  Timer? _pollTimer;
  bool _disposed = false;
  bool _playbackStarted = false;
  bool _playLoggedForCurrentTrack = false;
  int _currentAlbumStreak = 0;
  String? _lastAlbumName;
  Player? _videoPlayer;
  VideoController? _videoController;
  String? _cachedVideoUrl;
  bool _isVideoCached = false;
  bool _videoPrefetchDone = false;
  Future<void>? _pendingVideoFetch;
  StreamSubscription? _audioPositionSubscription;
  StreamSubscription? _videoPositionSubscription;
  bool _syncMonitorActive = false;
  bool _videoReady = false;

  List<VideoSource> get _videoSources => [
    VideoSource('LocalCache', _checkLocalVideoCache, priority: 1),
    VideoSource('YouTube', _fetchYouTubeVideo, priority: 2),
    VideoSource('Tidal', _fetchTidalVideo, priority: 3),
    VideoSource('Qobuz', _fetchQobuzVideo, priority: 4),
  ];

  String _currentVideoSource = 'None';

  VideoController? get videoController => _videoController;
  String? get cachedVideoUrl => _cachedVideoUrl;
  bool get isVideoCached => _isVideoCached;
  String get currentVideoSource => _currentVideoSource;

  void setLyricsReady(bool isReady) {
    state = state.copyWith(isLyricsReady: isReady);
  }

  @override
  AudioPlayerState build() {
    ref.onDispose(() {
      _disposed = true;
      _stopSyncMonitor();
      _pollTimer?.cancel();
      _audioPositionSubscription?.cancel();
      _videoPositionSubscription?.cancel();
      _player?.dispose();
      disposeVideo();
    });
    return const AudioPlayerState();
  }

  Player get _ensurePlayer {
    if (_player == null) {
      _player = Player();
      if (_player!.platform is NativePlayer) {
        try {
          (_player!.platform as NativePlayer).setProperty('cache', 'no');
          (_player!.platform as NativePlayer).setProperty('cache-on-disk', 'no');
          (_player!.platform as NativePlayer).setProperty('vo', 'null');
        } catch (e) {}
      }
      _log.i('MediaKit player initialized');
      _player!.stream.position.listen((p) {
        if (!_disposed) state = state.copyWith(position: p);
      });
      _player!.stream.duration.listen((d) {
        if (!_disposed) state = state.copyWith(duration: d);
      });
      _player!.stream.completed.listen((_) async {
        if (!_disposed) {
          if (!_playbackStarted) {
            _log.w('Ignoring premature completed event (playback not started yet)');
            return;
          }
          final s = state;
          final durationSeconds = s.duration.inSeconds > 0 ? s.duration.inSeconds : null;
          try {
            await StatsDatabase.instance.logPlay(
              trackId: s.trackId ?? 'unknown',
              trackName: s.trackName ?? 'Unknown',
              artistName: s.artistName ?? 'Unknown',
              albumName: s.albumName,
              coverUrl: s.coverUrl,
              source: s.source,
              durationSeconds: durationSeconds,
            );
            _playLoggedForCurrentTrack = true;
            ref.invalidate(achievementProgressProvider);
            try {
              await _updateSecretStats();
            } catch (_) {}
          } catch (e) {
            _log.w('Failed to log play stats: $e');
          }
          _log.i('Track completed, auto-advancing');
          state = state.copyWith(isPlaying: false, position: Duration.zero);
          await _autoAdvance();
        }
      });
      _player!.stream.error.listen((error) {
        _log.e('Player error stream: $error');
      });
      _player!.stream.log.listen((log) {
        _log.d('Player log: ${log.prefix} ${log.level} ${log.text}');
      });
      _player!.stream.audioParams.listen((params) {
        _playbackStarted = true;
        _log.i('Player audio params: format=${params.format} rate=${params.sampleRate} channels=${params.channelCount}');
      });
      _player!.stream.playlist.listen((playlist) {
        _log.d('Player playlist updated: ${playlist.medias.length} items, index=${playlist.index}');
      });
      _player!.stream.playing.listen((isPlaying) {
        _log.d('Player playing state: $isPlaying');
      });
      _player!.stream.buffering.listen((isBuffering) {
        _log.d('Player buffering: $isBuffering');
      });
      _player!.setVolume(100.0);
    }
    return _player!;
  }
}

final audioPlayerProvider = NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  AudioPlayerNotifier.new,
);
