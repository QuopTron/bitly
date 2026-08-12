export '../cache/player_state.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import '../../injection.dart';
import '../../frontend/shared/models/performance_profile.dart';
import '../rpc/backend_service.dart';
import '../cache/settings_cache.dart';
import '../cache/download_cache.dart';
import '../../frontend/shared/models/feed_models.dart';
import '../../frontend/shared/utils/download_strategy.dart';
import '../cache/playback_cache.dart';
import '../cache/player_state.dart';
import 'queue_cubit.dart';
import 'scrobble_service.dart';
import 'verification_service.dart';

class PlayerCubit extends Cubit<AudioPlayerState> {
  final Player _player = Player();
  final QueueCubit _queueCubit;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _compSub;
  StreamSubscription<bool>? _playSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _queueSub;
  VoidCallback? _perfSub;
  /// Map of trackId → actual file path from download history.
  final Map<String, String> _localFiles = {};
  String? _downloadPath;
  /// Set of normalized track IDs that are being streamed (not local).
  /// Used to clean up cached files after playback completes.
  final Set<String> _streamedTrackIds = {};

  /// Set of normalized track IDs of temp files downloaded for streaming.
  /// Cleaned up after playback completes or on app close.
  final Set<String> _tempStreamFiles = {};

  /// Cache of resolved stream URLs (normalized trackId → (url, withFallback)).
  /// [withFallback] is true when the URL came from the download pipeline (a
  /// produced file on disk, same logic as a real download); false when it is
  /// just a direct http(s) probe from a background preload. Taps reuse only
  /// withFallback results — a preload-only URL is re-resolved WITH the
  /// fallback so playback gets the download-quality copy, and that preloaded
  /// URL becomes the plan B if the download pipeline comes up empty.
  final Map<String, (String url, bool withFallback)> _streamUrlCache = {};

  /// Normalized track IDs that are ready to play instantly (stream already
  /// resolved or a local file available). Backs the "ready" indicator shown on
  /// track cards so the user can tell at a glance what plays with zero wait.
  final ValueNotifier<Set<String>> readyTracks = ValueNotifier(const <String>{});

  /// Marks [normalizedId] as ready-to-play and notifies listeners of the set.
  void _markReady(String normalizedId) {
    final current = readyTracks.value;
    if (current.contains(normalizedId)) return;
    readyTracks.value = {...current, normalizedId};
  }

  /// In-flight stream resolution futures (normalized trackId → (Future,
  /// wasPreload)). Deduplicates concurrent resolutions so a track being
  /// prefetched in the background is reused (not started from scratch) if the
  /// user taps it now. Preloads run WITHOUT the download fallback; when the
  /// user actually plays such a track, a fresh resolution WITH the fallback is
  /// started instead of reusing the (likely null) preload result.
  final Map<String, (Future<String?>, bool)> _streamFutures = {};

  /// Consecutive decode errors for the current track. Used to break libmpv's
  /// infinite retry loop on a resource the player can't decode.
  int _consecutiveErrors = 0;
  /// While true, player errors are ignored: we are falling back from a local
  /// file that failed to decode to its streaming URL, and the old media may
  /// keep emitting a few residual errors until it is stopped.
  bool _recovering = false;
  /// The URI last handed to the player (for diagnostics / broken tracking).
  String? _lastOpenedUri;
  /// Stream URLs that already failed to decode (normalized trackId → url),
  /// so a re-resolve can avoid handing the same dead URL back to the player.
  final Map<String, String> _brokenUrlByTrack = {};

  /// Last backend/stream resolve error text for the current open attempt, so a
  /// silent "Could not resolve URI" can be surfaced with a useful message.
  String _lastStreamError = '';

  /// Structured classification of the last stream-resolve failure (e.g.
  /// "verification_required") and the provider that needs it, so playback can
  /// open the correct verification flow instead of a generic error message.
  String _lastStreamErrorType = '';
  String _lastStreamService = '';

  /// Prefetch throttle: at most [prefetchSlots] stream resolutions in flight at
  /// once. Background prefetches can otherwise fire a dozen concurrent heavy
  /// cross-provider searches that saturate the executor and make real playback
  /// wait >60s (RPC timeout). Excess tracks queue up and drain as slots free.
  static const int prefetchSlots = 2;
  int _prefetchUsed = 0;
  final List<FeedItem> _prefetchQueue = [];

  void _schedulePrefetch(FeedItem track) {
    if (_prefetchUsed >= prefetchSlots) {
      _prefetchQueue.add(track);
      return;
    }
    _prefetchUsed++;
    unawaited(_runPrefetch(track));
  }

  Future<void> _runPrefetch(FeedItem track) async {
    try {
      await _resolveStreamUrl(track, isPreload: true);
    } finally {
      _prefetchUsed--;
      if (_prefetchQueue.isNotEmpty) {
        final next = _prefetchQueue.removeAt(0);
        _prefetchUsed++;
        unawaited(_runPrefetch(next));
      }
    }
  }

  /// Local play logging service (Drift).
  PlaybackCache? _playbackCache;

  /// Cache TTL para _localFiles: se inicializa desde DownloadSettings.
  /// Default 30s si no hay settings cargados aún.
  Duration _localFilesTTL = const Duration(seconds: 30);
  DateTime? _localFilesLoadedAt;
  /// Almacena el timestamp ISO 8601 de la última carga de _localFiles.
  /// En cargas delta posteriores, se pasa como 'since' al backend para
  /// obtener solo los cambios desde esta fecha.
  String? _lastLoadTimestamp;

  /// Exposed so UI (e.g. NowPlayingPage) can look up local video files.
  String? get downloadPath => _downloadPath;
  String get audioQuality => _audioQuality;
  String get videoQuality => _videoQuality;
  bool get videoEnabled => _videoEnabled;
  bool get lyricsEnabled => _lyricsEnabled;

  /// Preloaded lyrics (LRC) for the current track — loaded when track starts.
  String? preloadedLyrics;
  /// Preloaded video URL for the current track — resolved when track starts.
  String? preloadedVideoUrl;
  bool preloadingLyrics = false;
  bool preloadingVideo = false;
  bool _ready = false;
  FeedItem? _pendingTrack;
  String _audioQuality = 'flac';
  String _videoQuality = '720p';
  bool _videoEnabled = false;
  bool _lyricsEnabled = true;

  PlayerCubit(this._queueCubit) : super(const AudioPlayerState()) {
    _initPlayer();
    _initDownloadPath();
    _listenQueue();
    _perfSub = _onPerfChanged;
    sl<ValueNotifier<PerformanceProfile>>().addListener(_onPerfChanged);
  }

  /// Reflects the selected performance profile's quality on live streaming
  /// (audio + video) without requiring an app restart.
  void _onPerfChanged() {
    final profile = sl<ValueNotifier<PerformanceProfile>>().value;
    if (_audioQuality != profile.audioQuality) {
      _audioQuality = profile.audioQuality;
    }
    _videoEnabled = profile.level != PerfLevel.low;
  }

  Future<void> _initDownloadPath() async {
    try {
      _downloadPath = await sl<SettingsCache>().getDownloadPath();
      final settings = await sl<SettingsCache>().getDownloadSettings();
      _audioQuality = settings.audioQuality;
      _videoQuality = settings.videoQuality;
      _videoEnabled = settings.videoEnabled;
      _lyricsEnabled = settings.lyricsEnabled;
      _localFilesTTL = Duration(seconds: settings.localFilesTtlSeconds);
    } catch (_) {
      // Si falla la carga inicial, igual marcamos _ready para no bloquear la reproducción.
      // El streaming usará defaults (flac / 720p) y el path local se resolverá sobre la marcha.
    }

    // Cargar archivos locales ANTES de marcar _ready para que _openTrack()
    // pueda encontrar tracks descargados inmediatamente.
    // Inicializar PlaybackCache para logging de plays
    _playbackCache = sl<PlaybackCache>();
    await _loadLocalFiles();

    _ready = true;
    if (_pendingTrack != null) {
      _openTrack(_pendingTrack!);
      _pendingTrack = null;
    }
  }

  /// Carga el historial de descargas para saber qué archivos existen localmente.
  /// Indexa tanto por canonical ID como por providerTrackId para que
  /// _resolveUri() pueda encontrar tracks por cualquiera de los dos.
  ///
  /// [delta]=true: solo obtiene entradas nuevas desde [_lastLoadTimestamp]
  /// y hace merge en el mapa existente (sin limpiarlo).
  /// [delta]=false (default): carga completa, reemplaza todo el mapa.
  Future<void> _loadLocalFiles({bool delta = false}) async {
    try {
      final json = await sl<DownloadCache>().getDownloadHistory(
        since: delta ? _lastLoadTimestamp : null,
      );
      if (json.isNotEmpty && json != '[]') {
        final list = jsonDecode(json) as List;

        if (!delta) {
          _localFiles.clear();
        }

        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final tid = (m['id'] ?? m['trackId'] ?? m['track_id'] ?? '').toString();
          final fp = (m['filePath'] ?? m['file_path'] ?? '') as String;
          if (tid.isNotEmpty && fp.isNotEmpty && await File(fp).exists()) {
            _localFiles[tid] = fp;
          }

          final providerTrackId = (m['providerTrackId'] ?? '').toString();
          if (providerTrackId.isNotEmpty && providerTrackId != tid && await File(fp).exists()) {
            _localFiles[providerTrackId] = fp;
          }
        }
      }

      // Escanear el directorio de descargas solo en full load para no
      // repetir la operación de filesystem en cada refresh.
      if (!delta && _downloadPath != null) {
        final dir = Directory(_downloadPath!);
        if (await dir.exists()) {
          final entries = await dir.list().toList();
          for (final entry in entries) {
            if (entry is File) {
              final fname = entry.path.split(Platform.pathSeparator).last;
              final stem = fname.replaceAll(RegExp(r'\.[^.]+$'), '');
              if (!_localFiles.containsKey(stem)) {
                _localFiles[stem] = entry.path;
              }
            }
          }
        }
      }

      _localFilesLoadedAt = DateTime.now();
      _lastLoadTimestamp = DateTime.now().toUtc().toIso8601String();
    } catch (_) {}
  }

  void _initPlayer() {
    _posSub = _player.stream.position.listen((pos) {
      if (!isClosed) emit(state.copyWith(position: pos));
    });
    _durSub = _player.stream.duration.listen((dur) {
      if (!isClosed) emit(state.copyWith(duration: dur));
    });
    _compSub = _player.stream.completed.listen((_) {
      if (!isClosed) _onTrackCompleted();
    });
    _playSub = _player.stream.playing.listen((playing) {
      if (!isClosed) {
        emit(state.copyWith(
          playbackState: playing ? PlayerPlaybackState.playing : PlayerPlaybackState.paused,
        ));
      }
    });
    _errorSub = _player.stream.error.listen((error) {
      // While recovering from a decode failure, ignore residual errors from
      // the media being stopped; otherwise the storm re-triggers give-up.
      if (_recovering) return;
      // A failing resource (403/expired/HTML) makes libmpv reopen it in a tight
      // loop, spamming "Error decoding audio" forever. Break the loop: after a
      // few consecutive failures we stop the player and mark the track failed.
      _consecutiveErrors++;
      // ignore: avoid_print
      print('[PlayerCubit] Player error ($_consecutiveErrors): $error');
      if (_consecutiveErrors >= 3) {
        // ignore: avoid_print
        print('[PlayerCubit] Giving up on track after repeated decode errors');
        _consecutiveErrors = 0;
        final failed = _queueCubit.state.current;
        final deadUri = _lastOpenedUri ?? '';
        if (failed != null) {
          _brokenUrlByTrack[normalizeTrackId(failed.id)] = deadUri;
        }
        // A local file that can't be decoded would otherwise reopen forever.
        // Stop the failing media FIRST (this breaks libmpv's error storm), then
        // mark the file broken and retry the SAME track via streaming so the
        // user's tap actually plays instead of erroring out.
        if (failed != null && deadUri.startsWith('file://')) {
          _recovering = true;
          unawaited(_player.stop());
          unawaited(_openTrack(failed));
          return;
        }
        unawaited(_player.stop());
        if (!isClosed) {
          emit(state.copyWith(playbackState: PlayerPlaybackState.error));
        }
      }
    });
  }

  void _listenQueue() {
    _queueSub = _queueCubit.stream.listen((queueState) {
      if (queueState.hasCurrent && queueState.current != null) {
        if (!_ready) {
          _pendingTrack = queueState.current;
          return;
        }
        _openTrack(queueState.current!);
      } else if (!queueState.hasCurrent) {
        _player.stop();
        emit(AudioPlayerState(volume: state.volume));
      }
    });
  }

  Future<void> _openTrack(FeedItem track) async {
    await _refreshLocalFiles();
    _lastStreamError = '';
    _lastStreamErrorType = '';
    _lastStreamService = '';

    // 1. Try local files first (skip a local file that already failed to
    //    decode, so a corrupt/undecodable download falls back to streaming
    //    instead of reopening the dead file forever).
    String? uri = _resolveLocalUri(track);
    if (uri != null) {
      final broken = _brokenUrlByTrack[normalizeTrackId(track.id)];
      if (broken != null && uri == broken) uri = null;
    }
    if (uri != null) _markReady(normalizeTrackId(track.id));

    // 2. If not local, resolve a live stream URL (progressive playback via
    //    media_kit). Reuses an in-flight prefetch resolution when available.
    if (uri == null) {
      // Hard gate: before resolving a stream from a signed-session (Cloudflare)
      // source, make sure its token is usable. If it isn't, open the
      // verification modal NOW so the token is refreshed instead of failing
      // mid-playback (the user must complete it before this song can play).
      if (!await _ensureSignedForSource(track)) {
        final display = VerificationService()
            .sourceDisplayName(track.source ?? '');
        VerificationService().showNotice(
          'Sesión de $display no verificada — completa la verificación '
              'para reproducir esta canción.');
        return;
      }
      uri = await _resolveStreamUrl(track);
    }

    if (uri == null) {
      final raw = _lastStreamError.trim();
      final rawLower = raw.toLowerCase();
      final needsVerification = _lastStreamErrorType.toLowerCase() == 'verification_required' ||
          rawLower.contains('verify_required') ||
          rawLower.contains('verification required') ||
          rawLower.contains('verify required');
      String? msg;
      if (needsVerification) {
        final service = _lastStreamService.isNotEmpty
            ? _lastStreamService
            : (track.source ?? '');
        final display = VerificationService()
            .sourceDisplayName(service);
        msg = display.isNotEmpty
            ? 'Sesión de $display no verificada — completa la verificación '
                'para reproducir esta canción.'
            : 'Sesión no verificada — completa la verificación para '
                'reproducir esta canción.';
        // Open the verification modal for the provider that actually needs it
        // (e.g. amazon reached during fallback), so the session can be
        // refreshed right away instead of leaving playback dead.
        unawaited(_verifyServiceForPlayback(service, display));
      } else if (raw.contains('429') ||
          rawLower.contains('rate limit') ||
          rawLower.contains('too many')) {
        msg = 'Proveedor temporalmente saturado (429) — inténtalo de nuevo '
            'en unos segundos.';
      } else if (raw.isNotEmpty) {
        msg = 'No se pudo obtener un stream original para esta canción.';
      }
      if (msg != null) {
        emit(state.copyWith(
          playbackState: PlayerPlaybackState.error,
          errorMessage: msg,
        ));
        // ignore: avoid_print
        print('[PlayerCubit] Could not resolve URI for ${track.id}: $msg');
        if (!needsVerification) VerificationService().showNotice(msg);
      } else {
        // ignore: avoid_print
        print('[PlayerCubit] Could not resolve URI for ${track.id}');
      }
      _recovering = false;
      return;
    }

    // ignore: avoid_print
    print('[PlayerCubit] Opening: $uri');
    // TEMP diagnostic: confirm the playing track matches the displayed one
    // ignore: avoid_print
    print('[PLAYSYNC] open id=${track.id} name=${track.name} artists=${track.artists} '
        'coverUrl=${track.coverUrl} isrc=${track.isrc} uri=$uri');
    _lastOpenedUri = uri;
    _consecutiveErrors = 0;
    _recovering = false;
    try {
      await _player.open(Media(uri));
      await _player.play();
    } catch (e) {
      // ignore: avoid_print
      print('[PlayerCubit] Failed to open/play: $e');
    }

    unawaited(_preloadNeighbors());

    preloadedLyrics = null;
    preloadedVideoUrl = null;
    preloadingLyrics = false;
    preloadingVideo = false;

    unawaited(_preloadLyrics(track));
    unawaited(_preloadVideo(track));

    final scrobble = ScrobbleService();
    if (scrobble.hasLastfm || scrobble.hasListenBrainz) {
      unawaited(scrobble.updateNowPlaying(
        artist: track.artists ?? '',
        track: track.name,
        album: track.albumName,
      ));
    }
  }

  /// Signed-session (Cloudflare) gate before playing a track [track].
  ///
  /// If the track's source needs a signed session (e.g. qobuz-web, amazon,
  /// deezer, pandora) and that session is NOT currently usable, this opens the
  /// Cloudflare verification modal so the token is refreshed right then.
  /// Returns true only when playback may proceed.
  Future<bool> _ensureSignedForSource(FeedItem track) async {    final source = track.source ?? '';
    if (!VerificationService.signedSessionSources.contains(source)) {
      return true; // source doesn't need a signed session
    }
    final service = VerificationService();
    if (!service.isReady) return true; // can't reach UI — let the backend try

    final backend = sl<BackendService>();
    // Fast path: token is already usable — nothing to do.
    try {
      final status = await backend.getSignedSessionStatus(source);
      if (status.authenticated) return true;
    } catch (_) {}

    // Ask the backend whether a fresh challenge is actually pending. If it
    // reports NONE, do NOT block: the token may already be up to date (the
    // status snapshot can lag, or this provider id may not map to a sandbox)
    // and the streaming layer will surface a real error if it truly can't
    // play. Blocking here would wrongly show a "not verified" message over a
    // token the user already refreshed.
    String url;
    try {
      url = await backend.getPendingVerificationUrl(source);
      if (url.isEmpty) {
        url = await backend.triggerExtensionVerification(source);
      }
    } catch (_) {
      return true; // couldn't even ask — don't block, let streaming decide
    }
    if (url.isEmpty) return true; // backend has no challenge → allow playback

    // There really is a challenge to complete: open the modal and only allow
    // playback once the user completes it.
    try {
      final grant = await service.showVerification(
        extId: source,
        displayName: service.sourceDisplayName(source),
        authUrl: url,
      );
      if (grant == null || grant.isEmpty) return false;
      return await backend.completeSignedSessionGrant(source, grant);
    } catch (e) {
      // ignore: avoid_print
      print('[PlayerCubit] Signed-session verification failed for $source: $e');
      return false;
    }
  }

  /// Opens the Cloudflare verification modal for [service] (a provider reached
  /// during fallback that needs a signed session, e.g. amazon) so the user can
  /// refresh its token. Fire-and-forget; the user's next tap retries playback.
  Future<void> _verifyServiceForPlayback(String service, String display) async {
    if (service.isEmpty) return;
    final svc = VerificationService();
    if (!svc.isReady) return;
    final backend = sl<BackendService>();
    try {
      final status = await backend.getSignedSessionStatus(service);
      if (status.authenticated) return;
    } catch (_) {}
    String url;
    try {
      url = await backend.getPendingVerificationUrl(service);
      if (url.isEmpty) {
        url = await backend.triggerExtensionVerification(service);
      }
    } catch (_) {
      return;
    }
    if (url.isEmpty) return;
    try {
      final grant = await svc.showVerification(
        extId: service,
        displayName: display.isNotEmpty ? display : service,
        authUrl: url,
      );
      if (grant == null || grant.isEmpty) return;
      await backend.completeSignedSessionGrant(service, grant);
    } catch (e) {
      // ignore: avoid_print
      print('[PlayerCubit] Verification failed for $service: $e');
    }
  }

  /// Decodes a backend RPC result into a Map when possible.
  ///
  /// Both backends return the Go response as a JSON *string* (Android returns
  /// it raw from the MethodChannel, desktop returns `result` which is itself a
  /// JSON-encoded string). Callers must decode it instead of assuming a Map,
  /// otherwise e.g. `result['audioUrl']` silently fails and playback reports
  /// "Could not resolve URI" even though the backend produced a stream.
  Map<String, dynamic>? _decodeRpcResult(dynamic result) {
    if (result == null) return null;
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    if (result is String && result.isNotEmpty) {
      try {
        final decoded = jsonDecode(result);
        return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _preloadLyrics(FeedItem track) async {
    if (!_lyricsEnabled || track.name.isEmpty || (track.artists ?? '').isEmpty) return;
    preloadingLyrics = true;
    try {
      final result = await sl<BackendService>().rpcCall('getLyricsLRCWithSource', {
        'track_name': track.name,
        'artist_name': track.artists ?? '',
        'duration_ms': 0,
      });
      final data = _decodeRpcResult(result);
      if (data != null) {
        final lyrics = data['lyrics'] as String? ?? '';
        final instrumental = data['instrumental'] == true;
        preloadedLyrics = (!instrumental && lyrics.isNotEmpty) ? lyrics : null;
      } else {
        preloadedLyrics = null;
      }
    } catch (_) {
      preloadedLyrics = null;
    }
    preloadingLyrics = false;
  }

  Future<void> _preloadVideo(FeedItem track) async {
    if (!_videoEnabled) return;
    preloadingVideo = true;
    try {
      String? videoUrl = _resolveLocalVideoUrl(track);
      if (videoUrl == null) {
        videoUrl = await downloadVideoToTemp(track);
      }
      preloadedVideoUrl = videoUrl;
    } catch (_) {
      preloadedVideoUrl = null;
    }
    preloadingVideo = false;
  }

  /// Returns the stream cache directory, creating it if needed.
  Future<Directory> _getStreamCacheDir() async {
    final appCacheDir = await getApplicationCacheDirectory();
    final dir = Directory('${appCacheDir.path}${Platform.pathSeparator}stream_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Deletes a temp stream file by normalized track ID.
  Future<void> _cleanupTempFile(String normalizedId) async {
    if (!_tempStreamFiles.remove(normalizedId)) return;
    try {
      final cacheDir = await _getStreamCacheDir();
      final sep = Platform.pathSeparator;
      for (final ext in ['flac', 'mp3']) {
        final file = File('${cacheDir.path}$sep$normalizedId.$ext');
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
  }

  /// Resolves a live stream URL for [track] via the Go backend, caching the
  /// result and deduplicating concurrent resolutions.
  ///
  /// If [track] was already being prefetched (in-flight future), the same
  /// future is awaited so playback serves whatever is already resolved instead
  /// of starting the resolution from scratch.
  Future<String?> _resolveStreamUrl(FeedItem track, {bool isPreload = false}) async {
    final key = normalizeTrackId(track.id);
    final cached = _streamUrlCache[key];
    // A preload may reuse any cached URL. A real tap may only reuse a result
    // that came from the download pipeline (withFallback); a preload-only
    // http(s) probe is re-resolved so playback uses the same logic as a
    // download (file produced, quality-transformed, DRM-decrypted).
    if (cached != null && (isPreload || cached.$2)) return cached.$1;
    final inFlight = _streamFutures[key];
    if (inFlight != null) {
      // A preload (no download fallback) is in flight but the user is now
      // actually playing this track — start a fresh resolution WITH the
      // fallback so playback still works.
      if (!isPreload && inFlight.$2) {
        _streamFutures.remove(key);
      } else {
        return inFlight.$1;
      }
    }

    final future = _resolveStreamUrlInner(track, isPreload: isPreload);
    _streamFutures[key] = (future, isPreload);
    try {
      final url = await future;
      if (url != null && url.isNotEmpty) {
        // Taps resolve through the download pipeline (withFallback=true);
        // background preloads only probe direct streams (withFallback=false).
        // Never let a late-finishing preload downgrade a better entry that a
        // tap already stored (both can be in flight for the same track).
        final current = _streamUrlCache[key];
        if (current == null || !isPreload || !current.$2) {
          _streamUrlCache[key] = (url, !isPreload);
        }
        _markReady(key);
        return url;
      }
      // A real tap that could not produce a download-quality copy still has
      // the preload's direct stream URL as plan B — better than silence.
      // Skip it if that probe URL already failed to decode on a prior open.
      if (!isPreload && cached != null && !cached.$2) {
        if (_brokenUrlByTrack[key] != cached.$1) return cached.$1;
      }
      return url;
    } finally {
      // Only remove our own entry: a concurrent tap may have replaced it with
      // a fresh (fallback-enabled) resolution.
      final current = _streamFutures[key];
      if (current != null && identical(current.$1, future)) {
        _streamFutures.remove(key);
      }
    }
  }

  Future<String?> _resolveStreamUrlInner(FeedItem track, {bool isPreload = false}) async {
    final name = track.name.trim();
    if (name.isEmpty) return null;
    try {
      final result = await sl<BackendService>().rpcCall('getStreamPackage', {
        'preferredProvider': track.source ?? '',
        'trackID': track.id,
        'quality': _audioQuality,
        'fetchLyrics': 'false',
        'trackName': name,
        'artistName': track.artists ?? '',
        'isrc': track.isrc ?? '',
        'durationMs': track.durationMs,
        // Cross-provider ids (album/artist/playlist detail tracks) let the
        // backend resolve via CheckAvailability on any provider instead of a
        // slow name search.
        'spotifyId': track.spotifyId ?? '',
        'deezerId': track.deezerId ?? '',
        'tidalId': track.tidalId ?? '',
        'qobuzId': track.qobuzId ?? '',
        // Background prefetches skip the download fallback (no full audio
        // downloads in the background); real taps allow it.
        'allowFallback': !isPreload,
        // A fallback tap can legitimately download a full FLAC (30s-90s on
        // slow networks) after walking several providers, so give the RPC a
        // comfortable window instead of the 60s defensive default.
      }, const Duration(seconds: 180));
      final data = _decodeRpcResult(result);
      if (data != null) {
        // The backend downloaded a real encrypted/DRM file (e.g. amazon FLAC)
        // that only needs ffmpeg to decrypt; no CLI ffmpeg runs on Android, so
        // we decrypt here via ffmpeg-kit and play the decrypted file.
        if (data['needsDecryption'] == true) {
          final dec = await _decryptForPlayback(data, track);
          if (dec != null && dec.isNotEmpty) return dec;
          if (!isPreload) {
            // ignore: avoid_print
            print('[PlayerCubit] Could not decrypt stream for ${track.id}');
          }
          return null;
        }
        final url = (data['audioUrl'] ?? '').toString();
        if (url.isNotEmpty) return url;
        final err = (data['error'] ?? '').toString();
        // NOTE: We deliberately resolve the stream BEFORE failing playback.
        // The Cloudflare verification modal, when needed, is opened proactively
        // in _ensureSignedForSource (called from _openTrack before we get
        // here), so a valid tap never reaches this point unverified.
        if (err.isNotEmpty && !isPreload) {
          // ignore: avoid_print
          print('[PlayerCubit] Stream resolve error from backend: $err');
          _lastStreamError = err;
          _lastStreamErrorType = (data['errorType'] ?? '').toString();
          _lastStreamService = (data['service'] ?? '').toString();
        }
      }
      return null;
    } catch (e) {
      if (!isPreload) {
        // ignore: avoid_print
        print('[PlayerCubit] Stream resolve error: $e');
        _lastStreamError = e.toString();
      }
      return null;
    }
  }

  /// Decrypts an encrypted/DRM stream file returned by the backend via
  /// ffmpeg-kit, writing the playable file into the stream cache, and returns a
  /// `file://` URL for it (or null on failure).
  Future<String?> _decryptForPlayback(Map<String, dynamic> data, FeedItem track) async {
    final src = (data['filePath'] ?? '').toString();
    final key = (data['decryptionKey'] ?? '').toString();
    if (src.isEmpty || key.isEmpty) return null;
    final srcFile = File(src);
    if (!await srcFile.exists()) return null;

    var ext = (data['outputExtension'] ?? '').toString().trim();
    if (ext.isEmpty) ext = '.flac';
    if (!ext.startsWith('.')) ext = '.$ext';
    final normalized = normalizeTrackId(track.id);
    final cacheDir = await _getStreamCacheDir();
    final outPath = '${cacheDir.path}${Platform.pathSeparator}$normalized.dec$ext';

    final args = '-decryption_key $key -y -i ${_q(src)} -c copy ${_q(outPath)}';
    try {
      final session = await FFmpegKit.execute(args);
      if (ReturnCode.isSuccess(await session.getReturnCode()) && await File(outPath).exists()) {
        _tempStreamFiles.add(normalized);
        return 'file://${outPath.replaceAll('\\', '/')}';
      }
      // ignore: avoid_print
      print('[PlayerCubit] ffmpeg-kit decrypt failed: ${await session.getAllLogsAsString()}');
    } catch (e) {
      // ignore: avoid_print
      print('[PlayerCubit] ffmpeg-kit error: $e');
    }
    try {
      if (await File(outPath).exists()) await File(outPath).delete();
    } catch (_) {}
    return null;
  }

  /// Quotes a path for the ffmpeg-kit command line.
  String _q(String p) => "'${p.replaceAll("'", "\\'")}'";

  /// Pre-resolves stream URLs for an observed context (e.g. the visible feed)
  /// so the first track the user taps plays instantly. Fire-and-forget, capped
  /// to [limit] tracks, honoring the preload profile and skipping any track
  /// already local or already cached/in-flight.
  void precacheContext(List<FeedItem> tracks, {int limit = 12}) {
    final profile = sl<ValueNotifier<PerformanceProfile>>().value;
    if (!profile.preloadEnabled) return;
    var added = 0;
    for (final track in tracks) {
      if (added >= limit) break;
      if (track.type != 'track') continue;
      if (track.name.trim().isEmpty) continue;
      final key = normalizeTrackId(track.id);
      if (_streamUrlCache.containsKey(key)) continue;
      if (_resolveLocalUri(track) != null) continue;
      _schedulePrefetch(track);
      added++;
    }
  }

  /// Pre-resolves stream URLs for upcoming and previous tracks in the queue so
  /// playback of the next/previous song is instant (no network/provider wait).
  /// Reuses local files when present and skips already-cached or in-flight ones.
  Future<void> _preloadNeighbors() async {
    final profile = sl<ValueNotifier<PerformanceProfile>>().value;
    if (!profile.preloadEnabled) return;
    final qState = _queueCubit.state;
    if (!qState.hasCurrent) return;

    final currentKey = normalizeTrackId(qState.current!.id);
    final toPreload = <FeedItem>{};
    // Upcoming tracks.
    for (int i = 1; i <= profile.preloadTracks; i++) {
      final idx = qState.currentIndex + i;
      if (idx >= qState.tracks.length) break;
      toPreload.add(qState.tracks[idx]);
    }
    // Previous tracks too.
    for (int i = 1; i <= profile.preloadTracks; i++) {
      final idx = qState.currentIndex - i;
      if (idx < 0) break;
      toPreload.add(qState.tracks[idx]);
    }

    for (final track in toPreload) {
      final key = normalizeTrackId(track.id);
      if (key == currentKey) continue;
      if (_streamUrlCache.containsKey(key)) continue;
      if (_resolveLocalUri(track) != null) continue;
      _schedulePrefetch(track);
    }
  }

  /// Resolves a local video file path for [track], or null if not found.
  String? _resolveLocalVideoUrl(FeedItem track) {
    if (_downloadPath == null) return null;
    final videoExts = ['mp4', 'webm', 'mkv', 'avi'];
    for (final ext in videoExts) {
      final path = '$_downloadPath\\${track.id}.$ext';
      if (File(path).existsSync()) return 'file://${path.replaceAll('\\', '/')}';
    }
    if ((track.name.isNotEmpty && track.artists != null && track.artists!.isNotEmpty)) {
      const invalid = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
      String sanitize(String s) {
        var r = s;
        for (final ch in invalid) r = r.replaceAll(ch, '_');
        r = r.replaceAll(RegExp(r'[. ]+$'), '');
        return r.isEmpty ? 'unknown' : r;
      }
      final stem = '${sanitize(track.artists!)} - ${sanitize(track.name)}';
      for (final ext in videoExts) {
        final path = '$_downloadPath\\$stem.$ext';
        if (File(path).existsSync()) return 'file://${path.replaceAll('\\', '/')}';
      }
    }
    return null;
  }

  /// Finds a previously downloaded background video in the cache dir.
  String? _existingCachedVideo(FeedItem track, Directory cacheDir) {
    final sep = Platform.pathSeparator;
    final candidates = <String>['${cacheDir.path}$sep${track.id}.mp4'];
    if (track.name.isNotEmpty && (track.artists ?? '').isNotEmpty) {
      const invalid = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
      String sanitize(String s) {
        var r = s;
        for (final ch in invalid) {
          r = r.replaceAll(ch, '_');
        }
        r = r.replaceAll(RegExp(r'[. ]+$'), '');
        return r.isEmpty ? 'unknown' : r;
      }
      candidates.add(
        '${cacheDir.path}$sep${sanitize(track.artists!)} - ${sanitize(track.name)}.mp4',
      );
    }
    for (final c in candidates) {
      if (File(c).existsSync()) return 'file://${c.replaceAll('\\', '/')}';
    }
    return null;
  }

  /// Downloads the YouTube background video for [track] into the app cache
  /// (stream_cache) via the Go backend and returns a playable file:// URL.
  /// The video is a separate visual feature (NowPlaying cover ↔ video toggle),
  /// never part of the audio stream resolution.
  Future<String?> downloadVideoToTemp(FeedItem track) async {
    try {
      final appCacheDir = await getApplicationCacheDirectory();
      final cacheDir = Directory('${appCacheDir.path}${Platform.pathSeparator}stream_cache');
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

      final existing = _existingCachedVideo(track, cacheDir);
      if (existing != null) return existing;

      final strategy = <String, dynamic>{
        'type': 'video',
        'track_id': track.id,
        'item_id': '${track.id}_video',
        'track_title': track.name,
        'artist_name': track.artists ?? '',
        'source': track.source ?? '',
        'isrc': track.isrc ?? '',
        'quality': _videoQuality,
        'output_dir': cacheDir.path,
      };
      final res = await sl<BackendService>().downloadByStrategy(jsonEncode(strategy));
      final data = _decodeRpcResult(res);
      final fp = (data?['filePath'] ?? data?['file_path'] ?? '').toString();
      if (fp.isEmpty || !await File(fp).exists()) return null;
      return 'file://${fp.replaceAll('\\', '/')}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshLocalFiles() async {
    // Solo recargar si el caché expiró (30s TTL), para no llamar a
    // getDownloadHistory en cada cambio de track.
    final now = DateTime.now();
    if (_localFilesLoadedAt != null &&
        now.difference(_localFilesLoadedAt!) < _localFilesTTL) {
      return;
    }
    await _loadLocalFiles();
    // _localFilesLoadedAt se actualiza dentro de _loadLocalFiles()
  }

  String? _resolveLocalUri(FeedItem track) {
    final idsToTry = {track.id, normalizeTrackId(track.id)};

    // 1. Try from download history map (real file path from DB)
    for (final id in idsToTry) {
      final localPath = _localFiles[id];
      if (localPath != null && File(localPath).existsSync()) {
        return 'file://${localPath.replaceAll('\\', '/')}';
      }
    }

    // 2. Try guessing by track.id + extension
    final sep = Platform.pathSeparator;
    final exts = ['flac', 'mp3', 'm4a', 'ogg', 'wav', 'aac', 'opus'];
    if (_downloadPath != null) {
      for (final id in idsToTry) {
        for (final ext in exts) {
          final byId = '$_downloadPath$sep$id.$ext';
          if (File(byId).existsSync()) {
            return 'file://${byId.replaceAll('\\', '/')}';
          }
          final byIdNoExt = '$_downloadPath$sep$id';
          if (File(byIdNoExt).existsSync()) {
            return 'file://${byIdNoExt.replaceAll('\\', '/')}';
          }
        }
      }
    }

    // 2.5 Last-resort local scan: try any file in download dir that starts with
    //     the track id (catches canonical-named files and hardlinks).
    if (_downloadPath != null) {
      try {
        final dir = Directory(_downloadPath!);
        if (dir.existsSync()) {
          final candidates = dir.listSync().whereType<File>();
          final idLower = idsToTry.map((e) => e.toLowerCase()).toSet();
          for (final f in candidates) {
            final fname = f.path.split(Platform.pathSeparator).last.toLowerCase();
            if (idLower.any((id) => fname.startsWith(id))) {
              return 'file://${f.path.replaceAll('\\', '/')}';
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  Future<void> _onTrackCompleted() async {
    if (isClosed) return;

    // media_kit can emit a spurious `completed` notification right after open()
    // (e.g. the decrypted local FLACs), often BEFORE the real duration is parsed
    // (duration still 0). Only advance when we have a real end-of-file: a known
    // duration (>0) with position at/near the end. If duration is still unknown,
    // treat it as premature — live/radio never send `completed` anyway, so this
    // cannot get stuck, and opens with missing duration must not skip to next.
    final durMs = state.duration.inMilliseconds;
    final posMs = state.position.inMilliseconds;
    if (durMs <= 0 || posMs < durMs - 1500) {
      // ignore: avoid_print
      print('[PlayerCubit] Ignoring premature completed (pos=$posMs/${durMs}ms)');
      return;
    }

    // Registrar play en el historial local (Drift) antes de avanzar la cola.
    final completedTrack = _queueCubit.state.current;
    if (completedTrack != null && _playbackCache != null) {
      final trackId = normalizeTrackId(completedTrack.id);
      final durMs = state.duration.inMilliseconds;
      unawaited(_playbackCache!.logPlay(
        trackId: trackId,
        trackName: completedTrack.name,
        artistName: completedTrack.artists ?? '',
        albumName: completedTrack.albumName,
        durationMs: durMs > 0 ? durMs : null,
        percentage: 100,
      ));
    }

    if (completedTrack != null) {
      final scrobble = ScrobbleService();
      if (scrobble.hasLastfm || scrobble.hasListenBrainz) {
        unawaited(scrobble.scrobble(
          artist: completedTrack.artists ?? '',
          track: completedTrack.name,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          album: completedTrack.albumName,
          duration: state.duration.inMilliseconds ~/ 1000,
        ));
      }
    }

    final completedTrackId = _normalizeCurrentId();
    if (completedTrackId != null) {
      if (_streamedTrackIds.remove(completedTrackId)) {
        unawaited(_cleanupStreamCache(completedTrackId));
      }
      unawaited(_cleanupTempFile(completedTrackId));
    }

    final hadNext = _queueCubit.next();
    // Si la cola terminó (no hay más tracks) y hay internet, intentar autoplay
    // con tracks similares (modo radio).
    if (!hadNext && _queueCubit.state.tracks.isNotEmpty) {
      await _tryAutoplay();
    }
  }

  /// Elimina entries de [_localFiles] indexadas por los IDs de provider dados.
  /// También remueve cualquier otra key que apunte al mismo file path
  /// (ej. canonical hash que comparte path con un providerTrackId).
  /// Llamado desde DownloadCubit después de borrar descargas.
  /// [deleteFiles] si es true, también borra los archivos físicos del disco.
  void removeLocalFilesProviderIds(List<String> providerIds, {bool deleteFiles = false}) {
    final pathsToRemove = <String>{};
    for (final id in providerIds) {
      final path = _localFiles.remove(id);
      if (path != null) pathsToRemove.add(path);
    }
    if (pathsToRemove.isNotEmpty) {
      _localFiles.removeWhere((_, v) => pathsToRemove.contains(v));
      if (deleteFiles) {
        for (final path in pathsToRemove) {
          _deleteLocalFile(path);
        }
      }
    }
  }

  /// Borra un archivo local del disco y sus sidecars (.lrc, .jpg, .png).
  void _deleteLocalFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
        final base = path.substring(0, path.lastIndexOf('.'));
        for (final ext in ['.lrc', '.jpg', '.png', '.jpeg']) {
          final sidecar = File('$base$ext');
          if (sidecar.existsSync()) sidecar.deleteSync();
        }
        final parent = file.parent;
        if (parent.existsSync() && parent.listSync().isEmpty) {
          parent.deleteSync();
        }
      }
    } catch (_) {}
  }

  /// Retorna el ID normalizado del track actual o null si no hay.
  String? _normalizeCurrentId() {
    final current = _queueCubit.state.current;
    if (current == null) return null;
    return normalizeTrackId(current.id);
  }

  /// Envía una solicitud DELETE al backend para eliminar el archivo cacheado
  /// del track stremeado en .stream_cache.
  /// No debe bloquear la reproducción, por eso se llama con unawaited().
  Future<void> _cleanupStreamCache(String normalizedId) async {
    try {
      final client = HttpClient();
      try {
        final url = 'http://127.0.0.1:55009/cache/delete/$normalizedId.flac';
        final request = await client.deleteUrl(Uri.parse(url));
        final response = await request.close();
        await response.drain();
      } finally {
        client.close();
      }
    } catch (_) {
      // Fallo silencioso — la limpieza de cache no debe interrumpir nada
    }
  }

  /// Intenta hacer autoplay: busca tracks similares al último reproducido
  /// y los añade a la cola.
  Future<void> _tryAutoplay() async {
    try {
      final lastTrack = _queueCubit.state.tracks.last;
      if (lastTrack.name.isEmpty || lastTrack.artists == null) return;

      final backend = sl<BackendService>();
      final json = await backend.rpcCall('getSimilarTracks', {
        'request': jsonEncode({
          'artist_name': lastTrack.artists,
          'track_name': lastTrack.name,
          'limit': 10,
          'exclude_ids': <String>[],
        }),
      });
      if (json == null || json == '' || json == '[]') return;

      final list = jsonDecode(json.toString()) as List;
      if (list.isEmpty) return;

      final similarTracks = list.map((e) {
        final m = e as Map<String, dynamic>;
        return FeedItem(
          id: (m['id'] ?? '').toString(),
          type: 'track',
          name: (m['name'] ?? '').toString(),
          artists: (m['artistName'] ?? '').toString(),
          coverUrl: (m['coverUrl'] ?? '').toString(),
          albumName: (m['albumName'] ?? '').toString(),
          isrc: (m['isrc'] ?? '').toString(),
          source: (m['source'] ?? 'deezer').toString(),
        );
      }).toList();

      // Reemplazar toda la cola con tracks similares (modo radio)
      _queueCubit.replaceQueue(similarTracks);
    } catch (_) {
      // Autoplay falló silenciosamente — no hay más tracks
    }
  }

  void play() => _player.play();

  void pause() => _player.pause();

  void togglePlayPause() {
    if (state.isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekToProgress(double fraction) async {
    final dur = state.duration;
    if (dur.inMilliseconds > 0) {
      await _player.seek(Duration(
        milliseconds: (dur.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
      ));
    }
  }

  void next() => _queueCubit.next();

  void previous() => _queueCubit.previous();

  void setVolume(double vol) {
    _player.setVolume(vol.clamp(0.0, 1.0));
    emit(state.copyWith(volume: vol.clamp(0.0, 1.0)));
  }

  @override
  Future<void> close() async {
    if (_perfSub != null) {
      sl<ValueNotifier<PerformanceProfile>>().removeListener(_onPerfChanged);
    }
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _compSub?.cancel();
    await _playSub?.cancel();
    await _errorSub?.cancel();
    await _queueSub?.cancel();
    // Clean up all temp stream files
    for (final id in _tempStreamFiles.toList()) {
      await _cleanupTempFile(id);
    }
    await _player.dispose();
    return super.close();
  }
}





