import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/playback_queue_provider.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/providers/stats_provider.dart';
import 'package:bitly/providers/view_mode_provider.dart';
import 'package:bitly/services/cache/video_cache_manager.dart';
import 'package:bitly/services/descargas/download_request_payload.dart';
import 'package:bitly/services/historial/history_database.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/services/estadísticas/stats_database.dart';
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/utils/logger.dart';
import 'package:media_kit/media_kit.dart' show Media, NativePlayer, Player;
import 'package:media_kit_video/media_kit_video.dart' show VideoController;

final _log = AppLogger('AudioPlayer');

class VideoSource {
  final String name;
  final Future<String?> Function(String, String) fetchFunction;
  final int priority;
  
  VideoSource(this.name, this.fetchFunction, {this.priority = 99});
}

class AudioPlayerState {
  final bool isPlaying;
  final bool isLoading;
  final bool isDownloading;
  final int downloadProgress;
  final String? trackId;
  final String? trackName;
  final String? artistName;
  final String? albumName;
  final String? coverUrl;
  final String? source;
  final String? localPath;
  final Duration position;
  final Duration duration;
  final bool isVideoReady;
  final bool isLyricsReady;
  final bool isAudioVideoSynced;
  final Duration audioVideoOffset;
  final VideoController? videoController;

  const AudioPlayerState({
    this.isPlaying = false,
    this.isLoading = false,
    this.isDownloading = false,
    this.downloadProgress = 0,
    this.trackId,
    this.trackName,
    this.artistName,
    this.albumName,
    this.coverUrl,
    this.source,
    this.localPath,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isVideoReady = false,
    this.isLyricsReady = false,
    this.isAudioVideoSynced = false,
    this.audioVideoOffset = Duration.zero,
    this.videoController,
  });

  AudioPlayerState copyWith({
    bool? isPlaying,
    bool? isLoading,
    bool? isDownloading,
    int? downloadProgress,
    String? trackId,
    String? trackName,
    String? artistName,
    String? albumName,
    String? coverUrl,
    String? source,
    String? localPath,
    Duration? position,
    Duration? duration,
    bool? isVideoReady,
    bool? isLyricsReady,
    bool? isAudioVideoSynced,
    Duration? audioVideoOffset,
    VideoController? videoController,
    bool clearTrack = false,
  }) {
    if (clearTrack) {
      return const AudioPlayerState();
    }
    return AudioPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      trackId: trackId ?? this.trackId,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      coverUrl: coverUrl ?? this.coverUrl,
      source: source ?? this.source,
      localPath: localPath ?? this.localPath,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isVideoReady: isVideoReady ?? this.isVideoReady,
      isLyricsReady: isLyricsReady ?? this.isLyricsReady,
      isAudioVideoSynced: isAudioVideoSynced ?? this.isAudioVideoSynced,
      audioVideoOffset: audioVideoOffset ?? this.audioVideoOffset,
      videoController: videoController ?? this.videoController,
    );
  }
}

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
  
  // Video source management
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

  Future<void> play({
    required String trackId,
    required String trackName,
    required String artistName,
    String? albumName,
    String? coverUrl,
    required String provider,
    String? isrc,
    String? quality,
    String? audioPath,
  }) async {
    _log.i('play() called: $trackName - $artistName via $provider');
    if (trackId == state.trackId && _player != null) {
      _log.i('Same track/player, resuming');
      await _ensurePlayer.play();
      state = state.copyWith(isPlaying: true);
      return;
    }

    _playLoggedForCurrentTrack = false;
    if (albumName != null && albumName == _lastAlbumName) {
      _currentAlbumStreak++;
    } else {
      _currentAlbumStreak = 1;
    }
    _lastAlbumName = albumName;

    // 1. Determinar ruta local ANTES de setear estado (evita contención con Go backend)
    String? localPath;
    if (audioPath != null && await fileExists(audioPath)) {
      localPath = audioPath;
    }
    localPath ??= await _findLocalTrack(trackId, trackName, artistName, isrc);

    // Resolver carátula local
    String? resolvedCoverUrl = coverUrl;
    if (localPath != null) {
      final cover = await _findLocalCover(localPath);
      if (cover != null) resolvedCoverUrl = cover;
    }

    // Cancelar operaciones pendientes
    _cachedVideoUrl = null;
    _isVideoCached = false;
    _videoPrefetchDone = false;
    _pendingVideoFetch?.ignore();
    _pendingVideoFetch = null;
    disposeVideo();
    _pollTimer?.cancel();

    // 2. Setear estado INICIAL (sin trackId — NO dispara lyricsListener aún)
    state = state.copyWith(
      isLoading: true,
      isDownloading: localPath == null,
      downloadProgress: 0,
      localPath: localPath,
      coverUrl: resolvedCoverUrl,
      source: provider,
      albumName: albumName,
      isVideoReady: false,
      isLyricsReady: false,
    );

    // 3. INICIAR descarga/reproducción PRIMERO (Go backend libre ahora)
    final playbackFuture = localPath != null
        ? _playFile(localPath)
        : _downloadAndPlay(trackId, trackName, artistName, provider, isrc, quality);

    // 4. Setear trackId (dispara lyricsListener — Go backend ya ocupado con descarga)
    state = state.copyWith(
      trackId: trackId,
      trackName: trackName,
      artistName: artistName,
    );

    _log.i('localPath=$localPath -> starting ${localPath != null ? "_playFile" : "_downloadAndPlay"}');

    // 5. Esperar reproducción (descarga ya en progreso, letras encoladas detrás)
    await playbackFuture;

    // 6. Iniciar video (después de que el audio ya arrancó)
    if (_pendingVideoFetch != null) {
      await _pendingVideoFetch;
    }
    if (_isVideoCached && _cachedVideoUrl != null && _videoController == null) {
      await _initVideoPlayer();
    }
  }

  Future<void> prefetchVideo(String trackName, String artistName) async {
    // Si ya está listo o ya se está cargando, no hacer nada
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

      // Ordenar fuentes por prioridad
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
            
            // Cachear localmente si es de YouTube (para futuro uso offline)
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

      // Si llegamos aquí, todas las fuentes fallaron
      _log.e('All video sources failed for: $trackName - $artistName');
      _isVideoCached = false;
      _cachedVideoUrl = null;
      _currentVideoSource = 'None';
      state = state.copyWith(isVideoReady: false);
      
    })();

    await _pendingVideoFetch;
    _pendingVideoFetch = null;
  }

  Future<void> _playFile(String localPath) async {
    _log.i('Playing local file: $localPath');
    state = state.copyWith(
      isLoading: false, isDownloading: false,
      downloadProgress: 100, localPath: localPath,
    );
    try {
      final mediaUri = Uri.file(localPath).toString();
      _log.d('Opening media: $mediaUri');
      _playbackStarted = false;
      await _ensurePlayer.open(Media(mediaUri)).timeout(const Duration(seconds: 15));
      await _ensurePlayer.play();
      state = state.copyWith(isPlaying: true);
      _log.i('Playback started: $localPath');
    } on TimeoutException {
      _log.e('Playback open timed out for: $localPath');
      state = state.copyWith(isLoading: false, isDownloading: false);
    } catch (e, st) {
      _log.e('Playback open/play failed for local file: $e\n$st');
      state = state.copyWith(isLoading: false, isDownloading: false);
    }
  }

  Future<String?> _findLocalTrack(
    String trackId, String trackName, String artistName, String? isrc,
  ) async {
    final candidates = <String?>{trackId, 'spotify:track:$trackId'};
    if (isrc != null && isrc.isNotEmpty) candidates.add(isrc);

    for (final id in candidates) {
      if (id == null || id.isEmpty) continue;
      var json = await HistoryDatabase.instance.getBySpotifyId(id);
      if (json == null && isrc != null && isrc.isNotEmpty) {
        json = await HistoryDatabase.instance.getByIsrc(isrc);
      }
      if (json != null) {
        final item = DownloadHistoryItem.fromJson(json);
        if (await fileExists(item.filePath)) return item.filePath;
      }
    }

    final json = await HistoryDatabase.instance.findByTrackAndArtist(
      trackName, artistName,
    );
    if (json != null) {
      final item = DownloadHistoryItem.fromJson(json);
      if (await fileExists(item.filePath)) return item.filePath;
    }

    return null;
  }

  Future<String?> _findLocalCover(String audioPath) async {
    try {
      final dir = audioPath.substring(0, audioPath.lastIndexOf(Platform.pathSeparator));
      final baseName = audioPath.substring(audioPath.lastIndexOf(Platform.pathSeparator) + 1);
      final nameWithoutExt = baseName.replaceFirst(RegExp(r'\.[^.]+$'), '');

      // Common cover file names
      final candidates = [
        '$dir${Platform.pathSeparator}cover.jpg',
        '$dir${Platform.pathSeparator}cover.png',
        '$dir${Platform.pathSeparator}$nameWithoutExt.jpg',
        '$dir${Platform.pathSeparator}$nameWithoutExt.png',
        '$dir${Platform.pathSeparator}${nameWithoutExt}_cover.jpg',
        '$dir${Platform.pathSeparator}${nameWithoutExt}_cover.png',
        '$dir${Platform.pathSeparator}Folder.jpg',
        '$dir${Platform.pathSeparator}folder.jpg',
      ];
      for (final c in candidates) {
        if (await fileExists(c)) return c;
      }
    } catch (e) {}
    return null;
  }

  Future<void> _downloadAndPlay(
    String trackId, String trackName, String artistName,
    String provider, String? isrc, String? quality,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final safeId = trackId.replaceAll(RegExp(r'[^\w]'), '_');

      final payload = DownloadRequestPayload(
        trackName: trackName,
        artistName: artistName,
        albumName: '',
        outputDir: tempDir.path,
        filenameFormat: 'play_$safeId',
        isrc: isrc ?? '',
        service: provider,
        source: provider,
        itemId: trackId,
        useExtensions: true,
        useFallback: true,
        isPremium: ref.read(settingsProvider).isPremium,
        premiumUntil: ref.read(settingsProvider).premiumUntil,
      );

      state = state.copyWith(downloadProgress: 50);
      _log.i('Downloading for playback: $trackName by $artistName via $provider');

      final result = await PlatformBridge
          .downloadByStrategy(payload: payload);
      final success = result['success'] == true;
      final filePath = result['file_path'] as String? ?? '';

      final file = File(filePath);
      if (success && filePath.isNotEmpty && await file.exists()) {
        final fileSize = await file.length();
        _log.i('Playback ready: $filePath ($fileSize bytes)');
        await _playFile(filePath);
      } else {
        _log.e('Playback download failed: ${result['error']}');
        state = state.copyWith(isLoading: false, isDownloading: false);
      }
    } on TimeoutException {
      _log.e('Playback download timed out for: $trackName by $artistName');
      state = state.copyWith(isLoading: false, isDownloading: false);
    } catch (e) {
      _log.e('Playback failed: $e');
      state = state.copyWith(isLoading: false, isDownloading: false);
    }
  }

  Future<void> startVideo(String trackName, String artistName) async {
    // If video is already initialized and ready, just return
    if (_videoController != null && _videoReady) {
      return;
    }
    
    // If we have cached video URL, try to initialize player
    if (_isVideoCached && _cachedVideoUrl != null) {
      try {
        _log.i('Initializing video player with cached URL (source: $_currentVideoSource)');
        await _initVideoPlayer();
        return;
      } catch (e) {
        _log.e('Video initialization failed, will try prefetch: $e');
        // Fall through to prefetch logic
      }
    }
    
    // If video is marked as ready but no controller, try to initialize
    if (state.isVideoReady) {
      _log.w('startVideo: isVideoReady=true but no cached URL, attempting prefetch');
      await prefetchVideo(trackName, artistName);
      if (_isVideoCached && _cachedVideoUrl != null) {
        await _initVideoPlayer();
      }
      return;
    }
    
    // If there's already a pending fetch, wait for it
    if (_pendingVideoFetch != null) {
      _log.i('Waiting for pending video fetch...');
      await _pendingVideoFetch;
      if (_isVideoCached && _cachedVideoUrl != null) {
        await _initVideoPlayer();
      }
      return;
    }
    
    // If we get here, start the prefetch process
    _log.i('No cached video, starting prefetch process');
    await prefetchVideo(trackName, artistName);
    
    if (!_isVideoCached || _cachedVideoUrl == null) {
      _log.w('Video prefetch completed but no video available');
      throw Exception('No video available from any source');
    }
  }

  bool _videoReady = false;

  Future<void> _initVideoPlayer() async {
    if (_videoController != null) return;
    final url = _cachedVideoUrl;
    if (url == null) return;
    
    // Dispose previous player if exists
    await _videoPlayer?.dispose();
    _videoPlayer = Player();

    if (_videoPlayer!.platform is NativePlayer) {
      try {
        (_videoPlayer!.platform as NativePlayer).setProperty('audio', 'no');
        // Remove problematic osc property that was causing errors
        // (_videoPlayer!.platform as NativePlayer).setProperty('vo', 'null');
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
        isAudioVideoSynced: false // Aún no sincronizado hasta que se reproduzca
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
        audioVideoOffset: Duration.zero
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
      // Si tenemos posición específica, buscar allí
      if (seekPosition != null && seekPosition > Duration.zero) {
        await _videoPlayer!.seek(seekPosition);
        _log.i('Video seeked to: $seekPosition');
      }

      // Iniciar reproducción
      await _videoPlayer!.play();
      _log.i('Video playback started');

      // Iniciar monitor de sincronización
      _startSyncMonitor();
      state = state.copyWith(isAudioVideoSynced: true, audioVideoOffset: Duration.zero);

    } catch (e) {
      _log.e('playVideo failed: $e');
      state = state.copyWith(isAudioVideoSynced: false);
      rethrow;
    }
  }

  void _startSyncMonitor() {
    // Evitar múltiples monitores
    if (_syncMonitorActive) {
      _log.i('Sync monitor already active');
      return;
    }

    _syncMonitorActive = true;
    _log.i('Starting audio-video sync monitor');

    // Monitorear posiciones de audio y video
    _audioPositionSubscription = _player?.stream.position.listen((audioPos) {
      if (_videoPlayer == null || !state.isAudioVideoSynced) return;
      
      _videoPlayer!.stream.position.first.then((videoPos) {
        final diff = (audioPos - videoPos).abs();
        
        // Si la diferencia es significativa (>200ms), resincronizar
        if (diff > const Duration(milliseconds: 200)) {
          _log.w('AV sync drift detected: ${diff.inMilliseconds}ms, resyncing...');
          _videoPlayer!.seek(audioPos);
          state = state.copyWith(audioVideoOffset: diff);
        }
      });
    });

    // También monitorear eventos de buffering
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
      
      // Obtener posición actual de audio
      final audioPos = _player!.state.position;
      
      // Buscar video a la posición de audio
      await _videoPlayer!.seek(audioPos);
      
      // Reiniciar el monitor de sincronización
      _stopSyncMonitor();
      _startSyncMonitor();
      
      state = state.copyWith(
        isAudioVideoSynced: true,
        audioVideoOffset: Duration.zero
      );
      
      _log.i('Audio-video resynced to: $audioPos');
      
    } catch (e) {
      _log.e('Resync failed: $e');
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
      audioVideoOffset: Duration.zero
    );
  }

  // Video Source Methods
  
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

  Future<void> togglePlayPause() async {
    if (_player == null) return;
    if (state.isPlaying) {
      await _player!.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await _player!.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<void> stop() async {
    await _logPlayIfQualified();
    _stopSyncMonitor();
    _pollTimer?.cancel();
    await _player?.stop();
    await _videoPlayer?.stop();
    state = state.copyWith(clearTrack: true);
  }

  Future<void> seek(Duration position) async {
    await _player?.seek(position);
    state = state.copyWith(position: position);
  }

  Future<void> _logPlayIfQualified() async {
    if (_playLoggedForCurrentTrack) return;
    final s = state;
    if (s.trackId == null || s.trackId == 'unknown') return;
    final position = s.position.inSeconds;
    const minSeconds = 30;
    if (position < minSeconds) return;
    _playLoggedForCurrentTrack = true;
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
      ref.invalidate(achievementProgressProvider);
    } catch (e) {
      _log.w('Failed to log partial play stats: $e');
    }
    try {
      await _updateSecretStats();
    } catch (e) {}
  }

  Future<void> _updateSecretStats() async {
     final hour = DateTime.now().hour;
     if (hour >= 0 && hour < 5) {
       // Stats secrets functionality removed
     }
  }

  Future<void> playLocalFile({
    required String filePath,
    required String trackName,
    required String artistName,
    String? albumName,
    String? coverUrl,
    String? source,
  }) async {
    _pollTimer?.cancel();
    state = state.copyWith(
      isLoading: false,
      isDownloading: false,
      trackId: filePath,
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      coverUrl: coverUrl,
      source: source,
      downloadProgress: 100,
      localPath: filePath,
    );
    _playbackStarted = false;
    try {
      await _ensurePlayer.open(Media(Uri.file(filePath).toString())).timeout(const Duration(seconds: 15));
      await _ensurePlayer.play();
      state = state.copyWith(isPlaying: true);
    } on TimeoutException {
      _log.e('playLocalFile open timed out');
    } catch (e, st) {
      _log.e('playLocalFile failed: $e\n$st');
    }
  }

  Future<void> playFromQueue() async {
    final queue = ref.read(playbackQueueProvider);
    final current = queue.currentItem;
    if (current == null) return;

    await play(
      trackId: current.track.id,
      trackName: current.track.name,
      artistName: current.track.artistName,
      albumName: current.track.albumName,
      coverUrl: current.track.coverUrl,
      provider: current.track.source ?? 'deezer',
      isrc: current.track.isrc,
      audioPath: current.localPath,
    );
  }

  Future<void> playQueueNext() async {
    await _logPlayIfQualified();
    final queueNotifier = ref.read(playbackQueueProvider.notifier);
    queueNotifier.next();
    await playFromQueue();
  }

  Future<void> playQueuePrevious() async {
    await _logPlayIfQualified();
    final queueNotifier = ref.read(playbackQueueProvider.notifier);
    queueNotifier.previous();
    await playFromQueue();
  }

  Future<void> _autoAdvance() async {
    final queue = ref.read(playbackQueueProvider);
    if (queue.canGoNext) {
      await playQueueNext();
    } else {
      await _player?.pause();
    }
  }

  Future<void> playTrackList(List<Track> tracks, {int startIndex = 0, Map<String, String>? localPaths}) async {
    final items = <PlaybackQueueItem>[];
    for (final track in tracks) {
      final localPath = localPaths?[track.id];
      items.add(PlaybackQueueItem(
        track: track,
        localPath: localPath,
        isAvailableOffline: localPath != null,
      ));
    }

    ref.read(playbackQueueProvider.notifier).setQueue(items, startIndex: startIndex);
    await playFromQueue();
  }
}

final audioPlayerProvider = NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  AudioPlayerNotifier.new,
);
