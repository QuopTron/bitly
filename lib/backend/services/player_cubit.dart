export '../cache/player_state.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../injection.dart';
import '../../frontend/shared/models/performance_profile.dart';
import '../rpc/backend_service.dart';
import '../cache/settings_cache.dart';
import '../cache/download_cache.dart';
import '../../frontend/shared/models/feed_models.dart';
import '../../frontend/shared/utils/download_strategy.dart';
import '../cache/playback_cache.dart';
import '../cache/player_state.dart';
import 'item_fingerprint.dart';
import 'queue_cubit.dart';
import 'scrobble_service.dart';
import 'stream_decrypt.dart';
import 'verification_service.dart';

/// A resolved stream URL kept in the in-memory/persistent cache.
class _CachedStream {
  final String url;
  final bool withFallback;

  /// URL's own expiry (YouTube URLs carry an exact `expire` param), or null
  /// for local files / unknown — see [_expiryForUrl].
  final DateTime? expiresAt;

  const _CachedStream(this.url, this.withFallback, this.expiresAt);
}

/// Stream URLs whose own lifetime is within this window of expiring are
/// treated as stale and re-resolved (ArchiveTune uses the same 60s safety
/// margin) — a URL that dies mid-playback is worse than a cheap re-resolve.
const _urlExpirySafety = Duration(seconds: 60);

/// Conservative lifetime for direct http(s) streams that carry no explicit
/// expiry (soundcloud CDN, deezer CDN, ...). YouTube URLs carry their own
/// exact `expire` param which [_expiryForUrl] parses instead.
const _defaultStreamTtl = Duration(hours: 6);

class PlayerCubit extends Cubit<AudioPlayerState> {
  // TEMP-DIAG: debug log level so the listener below can see mpv's open
  // errors (403 etc.) while diagnosing dead YouTube URLs.
  final Player _player = Player(
    configuration: PlayerConfiguration(logLevel: MPVLogLevel.debug),
  );
  final QueueCubit _queueCubit;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _compSub;
  StreamSubscription<bool>? _playSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _queueSub;
  VoidCallback? _perfSub;

  // ── Crossfade state ────────────────────────────────────────────────
  // When true, the position listener will fade out near end-of-track and
  // the completion handler will fade in the next track.
  static const _crossfadeEnabled = true;
  static const _crossfadeDuration = Duration(seconds: 3);
  static const _crossfadeStartBeforeEnd = Duration(seconds: 5);
  bool _crossfadingOut = false;

  /// Map of trackId → actual file path from download history.
  final Map<String, String> _localFiles = {};
  String? _downloadPath;

  /// Set of normalized track IDs that are being streamed (not local).
  /// Used to clean up cached files after playback completes.
  final Set<String> _streamedTrackIds = {};

  /// Set of normalized track IDs of temp files downloaded for streaming.
  /// Cleaned up after playback completes or on app close.
  final Set<String> _tempStreamFiles = {};

  /// Cache of resolved stream URLs, keyed by `trackId|quality` so a quality
  /// change never serves a URL resolved at the wrong tier.
  /// [withFallback] is true when the URL came from the download pipeline (a
  /// produced file on disk, same logic as a real download); false when it is
  /// just a direct http(s) probe from a background preload. Taps reuse only
  /// withFallback results — a preload-only URL is re-resolved WITH the
  /// fallback so playback gets the download-quality copy, and that preloaded
  /// URL becomes the plan B if the download pipeline comes up empty.
  /// [expiresAt] tracks the URL's own lifetime (YouTube URLs carry an exact
  /// `expire` param): entries within 60s of expiry are treated as stale and
  /// re-resolved, so a dead URL is never served mid-playback. Local files
  /// (file://) never expire.
  final Map<String, _CachedStream> _streamUrlCache = {};

  /// Normalized track IDs that are ready to play instantly (stream already
  /// resolved or a local file available). Backs the "ready" indicator shown on
  /// track cards so the user can tell at a glance what plays with zero wait.
  final ValueNotifier<Set<String>> readyTracks = ValueNotifier(
    const <String>{},
  );

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

  /// Base URL of the in-process Go streaming proxy, started lazily on first
  /// YouTube playback. YouTube bot-gates some egress IPs: mpv's whole-file
  /// HTTP request gets 403 while small bounded Range requests (a real client's
  /// ≤1MB chunks) serve fine. googlevideo URLs are therefore played through
  /// the local proxy, which fetches upstream in bounded chunks and pipes them
  /// to mpv. Local files and non-YouTube URLs never go through it.
  String? _streamProxyBase;
  Future<String?>? _streamProxyFuture;

  /// Stream URLs that already failed to decode (normalized trackId → url),
  /// so a re-resolve can avoid handing the same dead URL back to the player.
  final Map<String, String> _brokenUrlByTrack = {};

  /// Per-track count of dead-file re-downloads (normalized trackId → count),
  /// so a provider that keeps producing undecodable files ends in an error
  /// state instead of an infinite re-download loop.
  final Map<String, int> _deadFileRetries = {};

  /// Per-track count of open-stall re-resolutions (normalized trackId → count).
  /// mpv fails dead/expired/403 stream opens without any Dart-visible error,
  /// so the stall watchdog re-resolves once; this caps the loop.
  final Map<String, int> _stallRetries = {};

  /// Tracks already recovered from a short/preview stream (normalized trackId)
  /// — a direct http stream that ended far before the track's real duration
  /// (a 30s clip served as the full song) triggers ONE automatic re-open via
  /// the download fallback (which validates full length); a second short
  /// completion of the same track falls through to normal queue advance.
  final Set<String> _previewRecoveredTracks = {};

  /// Tracks already recovered from a dead/truncated-stream EOF (normalized
  /// trackId) — a completion with a parsed duration that arrived with the
  /// position still ≤10% of it (empty proxy response, silent 403-as-EOF, or
  /// the proxy pipe breaking after its first chunk) triggers ONE automatic
  /// re-resolve of the SAME track; a second identical death falls through so
  /// the queue advances instead of sticking.
  final Set<String> _deadStreamRecovered = {};

  /// True while a switch to a new non-local track is resolving: the previous
  /// audio is paused and the UI shows buffering until the new stream is ready.
  bool _switchPending = false;

  /// Monotonic generation for [_openTrack]: a newer call supersedes older
  /// in-flight ones, so a slow stream resolution can never clobber a track
  /// that was opened after it (the "plays the next song but the UI stays on
  /// the current one / skips 2 by 2" race).
  int _openGeneration = 0;

  /// Generation captured when the last media finished opening. A `completed`
  /// event whose generation doesn't match belongs to media that was disposed
  /// by a newer open — it must not advance the queue ("changes at any second").
  int _openedAtGeneration = 0;

  /// Identity (id|source) of the track the last [_openTrack] is opening/opened.
  /// Lets [_listenQueue] ignore queue edits that don't change the current
  /// track (addNext, addToEnd, shuffle/repeat toggles, reorder) instead of
  /// reopening — and restarting — the track that is already playing.
  String? _openedTrackKey;

  /// True while a real end-of-file completion is advancing the queue, so the
  /// same-track emission from repeat-one (or a duplicate entry in the list)
  /// reopens instead of being skipped by the [_openedTrackKey] guard.
  bool _forceReopen = false;

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
  static const int prefetchSlots = 3;
  int _prefetchUsed = 0;
  final List<(FeedItem, bool)> _prefetchQueue = [];

  /// Queues a background stream resolution for [track]. Probe preloads only
  /// resolve direct streams (cheap); a full preload ([withFallback] true) runs
  /// the whole pipeline so the resolved URL/file is ready when the track is
  /// actually tapped — used for the single immediate-next queue track.
  void _schedulePrefetch(FeedItem track, {bool withFallback = false}) {
    if (_prefetchUsed >= prefetchSlots) {
      _prefetchQueue.add((track, withFallback));
      return;
    }
    _prefetchUsed++;
    unawaited(_runPrefetch(track, withFallback: withFallback));
  }

  Future<void> _runPrefetch(FeedItem track, {bool withFallback = false}) async {
    try {
      await _resolveStreamUrl(track,
          isPreload: true, withFallback: withFallback);
    } finally {
      _prefetchUsed--;
      if (_prefetchQueue.isNotEmpty) {
        final (nextTrack, nextFull) = _prefetchQueue.removeAt(0);
        _prefetchUsed++;
        unawaited(_runPrefetch(nextTrack, withFallback: nextFull));
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

  /// Fires with the preloaded background-video URL when a track's video is
  /// ready to play (used by the full player to auto-start the "canvas" video
  /// without waiting for a player-state emit).
  final ValueNotifier<String?> preloadedVideoReady = ValueNotifier<String?>(null);
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
    _loadPersistentStreamCache();
  }

  /// Persistent stream URL cache: survives app restarts.
  /// Key: `trackId|quality` → (url, expiry). Entries older than 4 hours, or
  /// whose own URL expiry has passed, are discarded (providers expire tokens).
  static const _persistentCacheKey = 'stream_url_cache_v3';
  static const _cacheMaxAge = Duration(hours: 4);
  static const _cacheMaxEntries = 50;

  Future<void> _loadPersistentStreamCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_persistentCacheKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now();
      for (final entry in map.entries) {
        final data = entry.value as Map<String, dynamic>;
        final url = data['url'] as String? ?? '';
        final ts = DateTime.tryParse(data['ts'] as String? ?? '');
        final exp = DateTime.tryParse(data['exp'] as String? ?? '');
        if (url.isNotEmpty &&
            ts != null &&
            now.difference(ts) < _cacheMaxAge &&
            (exp == null || now.add(_urlExpirySafety).isBefore(exp))) {
          _streamUrlCache[entry.key] = _CachedStream(url, true, exp);
        }
      }
    } catch (_) {}
  }

  Future<void> _savePersistentStreamCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final map = <String, dynamic>{};
      var count = 0;
      for (final entry in _streamUrlCache.entries) {
        if (count >= _cacheMaxEntries) break;
        // Only cache http(s) URLs (not local file:// paths)
        final url = entry.value.url;
        if (!url.startsWith('http')) continue;
        map[entry.key] = {
          'url': url,
          'ts': now.toIso8601String(),
          'exp': entry.value.expiresAt?.toIso8601String(),
        };
        count++;
      }
      await prefs.setString(_persistentCacheKey, jsonEncode(map));
    } catch (_) {}
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

  /// Applies download-settings quality choices to live streaming without an app
  /// restart. Called from the settings sheet (global state) so a quality change
  /// takes effect on the next resolved stream instead of only after relaunch.
  void applyDownloadSettings({
    String? audioQuality,
    String? videoQuality,
    bool? videoEnabled,
    bool? lyricsEnabled,
  }) {
    if (audioQuality != null && audioQuality != _audioQuality) {
      _audioQuality = audioQuality;
    }
    if (videoQuality != null && videoQuality != _videoQuality) {
      _videoQuality = videoQuality;
    }
    if (videoEnabled != null) {
      _videoEnabled = videoEnabled;
    }
    if (lyricsEnabled != null) {
      _lyricsEnabled = lyricsEnabled;
    }
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
          final tid =
              (m['id'] ?? m['trackId'] ?? m['track_id'] ?? '').toString();
          final fp = (m['filePath'] ?? m['file_path'] ?? '') as String;
          if (tid.isNotEmpty && fp.isNotEmpty && await File(fp).exists()) {
            _localFiles[tid] = fp;
          }

          final providerTrackId = (m['providerTrackId'] ?? '').toString();
          if (providerTrackId.isNotEmpty &&
              providerTrackId != tid &&
              await File(fp).exists()) {
            _localFiles[providerTrackId] = fp;
          }

          // Index by name-fingerprint so a downloaded track is found even when
          // it's played from a DIFFERENT extension's feed (same song, other
          // provider's id). This makes the local file win over streaming
          // regardless of the file's actual name (e.g. an amazon decrypted
          // "unknown.flac").
          final name =
              (m['trackName'] ?? m['track_name'] ?? m['trackName'] ?? '')
                  .toString();
          final artist =
              (m['artistName'] ?? m['artist_name'] ?? '') as String;
          if (name.isNotEmpty && fp.isNotEmpty && await File(fp).exists()) {
            _localFiles[fingerprintFromName(name, artist)] = fp;
          }

          // Index by ISRC — the canonical recording id shared by ALL
          // providers. A track downloaded from apple-music plays locally even
          // when its name/artist differ slightly on a spotify/deezer feed
          // (the same recording carries the same ISRC everywhere).
          final isrc = (m['isrc'] ?? '').toString();
          if (isrc.isNotEmpty && fp.isNotEmpty && await File(fp).exists()) {
            _localFiles[fingerprintIsrc(isrc)] = fp;
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
    // media_kit >= 1.2 enables `cache-on-disk` by default, which makes mpv try
    // to create a disk cache file in the OS temp directory. On Android that
    // directory is not writable, so mpv logs "Failed to create file cache" and
    // the demuxer never starts — position advances but there is no audio. The
    // in-memory cache (`cache: yes`) is enough for streaming; our download
    // pipeline already handles on-disk caching where it matters.
    try {
      (_player.platform as dynamic).setProperty('cache-on-disk', 'no');
    } catch (_) {}
    // media_kit defaults to `ao=opensles` on Android (API > 25), but OpenSL ES
    // is broken on several emulators/ROMs ("Configuration error: unknown key"
    // → position advances with no audible audio). `ao=audiotrack` is mpv's
    // modern Android audio output (used by mpv-android itself) and works on
    // both emulators and physical devices.
    try {
      (_player.platform as dynamic).setProperty('ao', 'audiotrack');
    } catch (_) {}
    // mpv's audiotrack AO negotiates FLOAT sample output by default
    // ("AO: [audiotrack] ... float"). Several Android emulator audio bridges
    // (LDPlayer, etc.) only handle PCM16 and render silence (or static) for
    // float buffers even though the guest mixer shows frames flowing and the
    // position advances. Regular Android apps (YouTube, games) all deliver
    // PCM16, which is why they sound fine while we don't. Force 16-bit PCM at
    // 48kHz — the standard Android AudioTrack format — so emulator bridges
    // receive samples they can actually render. Negligible quality impact:
    // mpv resamples with its high-quality resampler and streamed sources are
    // lossy (AAC/MP3) anyway.
    try {
      (_player.platform as dynamic).setProperty('audio-format', 's16');
    } catch (_) {}
    try {
      (_player.platform as dynamic).setProperty('audio-samplerate', '48000');
    } catch (_) {}
    // TEMP-DIAG: dump mpv logs to logcat while diagnosing dead YouTube URLs.
    _player.stream.log.listen((l) {
      final lvl = l.level.toString();
      if (lvl.contains('error') || lvl.contains('warn') ||
          l.prefix == 'ffmpeg' || l.prefix == 'stream' ||
          l.prefix == 'ao' || l.prefix == 'cplayer' ||
          l.prefix == 'ad' || l.prefix == 'af') {
        print('[MPV-DIAG] $lvl ${l.prefix}: ${l.text}');
      }
    });
    _posSub = _player.stream.position.listen((pos) {
      if (!isClosed) emit(state.copyWith(position: pos));
      // Crossfade: when near end-of-track, start fading out volume.
      if (_crossfadeEnabled && !_crossfadingOut) {
        final dur = state.duration;
        if (dur > Duration.zero && dur - pos <= _crossfadeStartBeforeEnd && dur - pos > Duration.zero) {
          _crossfadingOut = true;
          _fadeVolume(0, _crossfadeDuration);
          // Kick off the next track's full resolution NOW so it's ready
          // to play instantly when the current track completes. Without
          // this, the resolution starts only AFTER completion — adding
          // network latency to the crossfade gap.
          _eagerPreloadNext();
        }
      }
    });
    _durSub = _player.stream.duration.listen((dur) {
      if (!isClosed) emit(state.copyWith(duration: dur));
    });
    _compSub = _player.stream.completed.listen((_) {
      if (!isClosed) _onTrackCompleted();
    });
    _playSub = _player.stream.playing.listen((playing) {
      if (!isClosed) {
        if (playing) {
          _switchPending = false;
          emit(state.copyWith(playbackState: PlayerPlaybackState.playing));
        } else if (!_switchPending) {
          emit(state.copyWith(playbackState: PlayerPlaybackState.paused));
        }
        // While _switchPending (a new track is resolving), the player being
        // stopped does NOT downgrade the visible buffering state.
      }
    });
    _errorSub = _player.stream.error.listen((error) {
      // While recovering from a decode failure OR switching tracks (old media
      // paused mid-resolution), ignore residual errors from the media being
      // stopped; otherwise a quick local↔stream switch miscounts 3 errors and
      // wrongly kills the track that just started.
      if (_recovering || _switchPending) return;
      // A failing resource (403/expired/HTML) makes libmpv reopen it in a tight
      // loop, spamming "Error decoding audio" forever. Break the loop: after a
      // few consecutive failures we stop the player and mark the track failed.
      _consecutiveErrors++;
      // debug removed
      if (_consecutiveErrors >= 3) {

        _consecutiveErrors = 0;
        final failed = _queueCubit.state.current;
        final deadUri = _lastOpenedUri ?? '';
        if (failed != null) {
          _brokenUrlByTrack[normalizeTrackId(failed.id)] = deadUri;
        }
        // A local file that can't be decoded would otherwise reopen forever.
        // Stop the failing media FIRST (this breaks libmpv's error storm), then
        // delete the dead file, drop its cached resolution and retry the SAME
        // track so the next resolution re-downloads a fresh copy instead of
        // reopening the same broken file again. Re-downloads are bounded per
        // track so a provider that keeps producing undecodable files ends in
        // an error state instead of an infinite retry loop.
        if (failed != null && deadUri.startsWith('file://')) {
          final retries =
              (_deadFileRetries[normalizeTrackId(failed.id)] ?? 0) + 1;
          _deadFileRetries[normalizeTrackId(failed.id)] = retries;
          if (retries > 2) {
            _recovering = true;
            unawaited(_player.stop());
            if (!isClosed) {
              emit(state.copyWith(playbackState: PlayerPlaybackState.error));
            }
            return;
          }
          final failedNorm = normalizeTrackId(failed.id);
          _recovering = true;
          _brokenUrlByTrack[failedNorm] = deadUri;
          _streamUrlCache.remove(_streamCacheKey(failedNorm));
          unawaited(_deleteDeadUriFile(deadUri));
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
        final current = queueState.current!;
        final key = '${current.id}|${current.source}';
        // Skip unrelated queue edits (addNext/addToEnd/shuffle/repeat/reorder)
        // while the same track is still current — reopening it here restarts
        // the song and can race with the real advance. Only reopen when the
        // current track actually changed, the previous one just completed
        // (repeat-one re-emits the same index on purpose), or the current
        // track is in an error state (the user re-tapping a failed track must
        // retry it, not be silently ignored).
        if (key == _openedTrackKey &&
            !_forceReopen &&
            state.playbackState != PlayerPlaybackState.error) {
          return;
        }
        _forceReopen = false;
        unawaited(_openTrack(current));
      } else if (!queueState.hasCurrent) {
        _player.stop();
        emit(AudioPlayerState(volume: state.volume));
      }
    });
  }

  Future<void> _openTrack(FeedItem track) async {
    final gen = ++_openGeneration;
    _openedTrackKey = '${track.id}|${track.source}';
    await _refreshLocalFiles();
    // A newer _openTrack superseded us while we were on disk — abort quietly.
    if (gen != _openGeneration) return;
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
        // Reset the identity guard so re-tapping this track after completing
        // the verification retries instead of being skipped as "unchanged".
        _openedTrackKey = null;
        final display = VerificationService().sourceDisplayName(
          track.source ?? '',
        );
        VerificationService().showNotice(
          'Sesión de $display no verificada — completa la verificación '
          'para reproducir esta canción.',
        );
        return;
      }
      if (gen != _openGeneration) return;
      // Switch to a non-local track: stop the previous track's audio right now
      // so the user doesn't keep hearing the old song while the new one
      // resolves (which can take 20-30s on the download path), and surface a
      // buffering state so the UI doesn't look stuck on the new track.
      _switchPending = true;
      if (!isClosed) {
        emit(state.copyWith(playbackState: PlayerPlaybackState.buffering));
      }
      unawaited(_player.pause());
      uri = await _resolveStreamUrl(track);
      // A newer track started resolving/opening while we were waiting — don't
      // hand our stale URL to the player over the newer track.
      if (gen != _openGeneration) return;
    }

    if (uri == null) {
      _switchPending = false;
      // The open failed: drop the identity guard so the user can tap the same
      // track again to retry (otherwise it is silently skipped forever).
      _openedTrackKey = null;
      final raw = _lastStreamError.trim();
      final rawLower = raw.toLowerCase();
      final needsVerification =
          _lastStreamErrorType.toLowerCase() == 'verification_required' ||
          rawLower.contains('verify_required') ||
          rawLower.contains('verification required') ||
          rawLower.contains('verify required');
      String? msg;
      if (needsVerification) {
        final service =
            _lastStreamService.isNotEmpty
                ? _lastStreamService
                : (track.source ?? '');
        final display = VerificationService().sourceDisplayName(service);
        msg =
            display.isNotEmpty
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
        msg =
            'Proveedor temporalmente saturado (429) — inténtalo de nuevo '
            'en unos segundos.';
      } else if (raw.isNotEmpty) {
        msg = 'No se pudo obtener un stream original para esta canción.';
      }
      if (msg != null) {
        emit(
          state.copyWith(
            playbackState: PlayerPlaybackState.error,
            errorMessage: msg,
          ),
        );
        if (!needsVerification) VerificationService().showNotice(msg);
      }
      _recovering = false;
      return;
    }

    // Final supersede check right before touching the player.
    if (gen != _openGeneration) return;
    // googlevideo URLs play through the local chunked proxy (YouTube 403s
    // mpv's whole-file requests on bot-gated networks but serves ≤1MB bounded
    // ranges fine; the proxy fetches bounded chunks and pipes them to mpv).
    final String playUri = await _localProxyUrl(uri);
    final normalizedId = normalizeTrackId(track.id);
    _lastOpenedUri = playUri;
    _consecutiveErrors = 0;
    // A track that opened (or at least resolved) cleanly resets its dead-file
    // retry budget, so a later corrupt download gets fresh retries. Exception:
    // when the URI is the SAME file:// path that already failed to decode,
    // the retry budget is NOT reset — otherwise a corrupt source file that
    // gets re-downloaded to the same path (stream-cache files use a fixed
    // {id}.{ext} name) reopens forever: resolve → decode-fail ×3 → delete &
    // re-resolve → same path → budget wiped → infinite ~30s re-download loop.
    // Keeping the budget lets the 2-retry cap stop the loop with a visible
    // error instead of redownloading a dead file forever.
    if (playUri != _brokenUrlByTrack[normalizedId]) {
      _deadFileRetries.remove(normalizedId);
    }
    _recovering = false;
    _switchPending = false;
    try {
      final ytHeaders = _headersForUrl(playUri);
      // mpv only actually sends these headers when http-header-fields is set
      // on the mpv instance itself. media_kit's Media(httpHeaders:) applies
      // them from an on_load hook that looks the URL up in an internal
      // HashMap keyed by mpv's reported `path` vs normalizeURI() — with long
      // signed googlevideo URLs that lookup silently misses, mpv sends its
      // default User-Agent, and YouTube answers 403 Forbidden (curl with the
      // client UA gets 206 on the SAME url). Set the property directly so
      // every mpv request (playlist probe, ranges, redirects) carries the
      // right headers. Header values here never contain commas, so the
      // comma-joined list form parses correctly.
      try {
        await (_player.platform as dynamic).setProperty(
          'http-header-fields',
          ytHeaders == null || ytHeaders.isEmpty
              ? ''
              : ytHeaders.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join(','),
        );
      } catch (_) {}
      await _player.open(Media(playUri, httpHeaders: ytHeaders));
      // The main player is audio-only (video canvas uses its own Player in
      // the full player). Tell mpv to skip any video track so streams that
      // only expose video+audio (e.g. YouTube itag=18 fallback) decode their
      // audio instead of stalling on H.264 video decode with no video output.
      try {
        await (_player.platform as dynamic).setProperty('vid', 'no');
      } catch (_) {}
      await _player.play();
      // Re-apply the user's playback speed: media_kit resets rate to 1.0 on
      // every open().
      if (state.rate != 1.0) {
        try {
          await _player.setRate(state.rate);
        } catch (_) {}
      }
      // Soft fade-in on every new track (transición suave): starts the audio
      // at 0 and ramps to the user's volume in ~110ms so track changes and
      // manual skips don't click/pop or jump abruptly. Fire-and-forget so it
      // never adds latency to the open; a user volume change mid-ramp simply
      // gets re-applied on the last step.
      unawaited(_fadeInAudio());
      // Only a completion that happens with no newer open in flight can be a
      // real end-of-file; anything else belongs to media this open disposed.
      _openedAtGeneration = _openGeneration;
    } catch (e) {
      // debug removed
    }

    // Open-stall watchdog: mpv fails dead/expired/403 stream opens with NO
    // Dart-visible error (the media never produces a stream-error event, it
    // just never starts). Without this the player sits at 00:00 forever with
    // the dead URL winning every re-tap. A few seconds after a network open,
    // if the position has not advanced past zero, treat the URL as dead:
    // invalidate it and re-resolve the SAME track once through the download
    // pipeline (which validates formats before returning). Local files are
    // exempt (decode failures surface through the error listener instead) and
    // a newer open supersedes the check.
    if (playUri.startsWith('http://') || playUri.startsWith('https://')) {
      final watchGen = _openGeneration;
      final watchKey = normalizedId;
      Future<void> checkStall() async {
        if (isClosed) return;
        if (gen != _openGeneration || watchGen != _openedAtGeneration) return;
        // Only when the position truly never started moving. A slow network
        // buffer that eventually delivers must not be cut off.
        if (_player.state.position >= const Duration(seconds: 1)) return;
        // Give buffering/preview-probes a little more time before judging.
        await Future<void>.delayed(const Duration(seconds: 6));
        if (isClosed) return;
        if (gen != _openGeneration || watchGen != _openedAtGeneration) return;
        if (_player.state.position >= const Duration(seconds: 1)) return;
        if (_player.state.playing == false) return;
        final retries = _stallRetries[watchKey] ?? 0;
        if (retries >= 1) return; // one fresh attempt is enough
        _stallRetries[watchKey] = retries + 1;
        debugPrint(
          '[Player] Open stalled at 00:00 for $watchKey — re-resolving fresh.',
        );
        _streamUrlCache.remove(_streamCacheKey(watchKey));
        _brokenUrlByTrack[watchKey] = playUri;
        // Let the re-open pass the "same track" guard and reach resolution.
        _forceReopen = true;
        unawaited(_openTrack(track));
      }

      unawaited(
        Future<void>.delayed(const Duration(seconds: 8), checkStall),
      );
    }

    unawaited(_preloadNeighbors());

    preloadedLyrics = null;
    preloadedVideoUrl = null;
    preloadedVideoReady.value = null;
    preloadingLyrics = false;
    preloadingVideo = false;

    unawaited(_preloadLyrics(track));
    unawaited(_preloadVideo(track));

    final scrobble = ScrobbleService();
    if (scrobble.hasLastfm || scrobble.hasListenBrainz) {
      unawaited(
        scrobble.updateNowPlaying(
          artist: track.artists ?? '',
          track: track.name,
          album: track.albumName,
        ),
      );
    }
  }

  /// Signed-session (Cloudflare) gate before playing a track [track].
  ///
  /// If the track's source needs a signed session (e.g. qobuz-web, amazon,
  /// deezer, pandora) and that session is NOT currently usable, this opens the
  /// Cloudflare verification modal so the token is refreshed right then.
  /// Returns true only when playback may proceed.
  Future<bool> _ensureSignedForSource(FeedItem track) async {
    final source = track.source ?? '';
    if (!VerificationService.signedSessionSources.contains(source)) {
      return true; // source doesn't need a signed session
    }
    final service = VerificationService();
    if (!service.isReady) return true; // can't reach UI — let the backend try

    final backend = sl<BackendService>();
    // Fast path: token is already usable — nothing to do. Bounded so a hung
    // backend status call can't stall a tap for 10s+ before streaming starts.
    try {
      final status = await backend
          .getSignedSessionStatus(source)
          .timeout(const Duration(seconds: 3));
      if (status.authenticated) return true;
    } catch (_) {}

    // Ask the backend whether a fresh challenge is actually pending. If it
    // reports NONE, do NOT block: the token may already be up to date (the
    // status snapshot can lag, or this provider id may not map to a sandbox)
    // and the streaming layer will surface a real error if it truly can't
    // play. Blocking here would wrongly show a "not verified" message over a
    // token the user already refreshed. Also bounded: a slow challenge probe
    // must not hold playback hostage for many seconds.
    String url;
    try {
      url = await backend
          .getPendingVerificationUrl(source)
          .timeout(const Duration(seconds: 4));
      if (url.isEmpty) {
        url = await backend
            .triggerExtensionVerification(source)
            .timeout(const Duration(seconds: 4));
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
      // debug removed
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
      // debug removed
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

  /// True when on wifi/ethernet; false on mobile data. On mobile data the
  /// stream quality is capped to save MB, but wifi keeps the user's full choice.
  /// Unknown/cached results default to wifi so normal playback isn't degraded
  /// when the check fails.
  static int _cacheThen = 0;
  static bool _lastIsWifi = true;
  Future<bool> _isWifiNetwork() async {
    try {
      if (DateTime.now().millisecondsSinceEpoch - _cacheThen > 30000) {
        final conns = await Connectivity().checkConnectivity();
        _lastIsWifi = conns.any(
          (c) =>
              c == ConnectivityResult.wifi || c == ConnectivityResult.ethernet,
        );
        _cacheThen = DateTime.now().millisecondsSinceEpoch;
      }
      return _lastIsWifi;
    } catch (_) {
      return true;
    }
  }

  /// Picks the quality sent to the backend for streaming. On mobile data,
  /// lossless -> 320kbps to keep the stream light; on wifi keep the user's
  /// chosen quality.
  Future<String> _effectiveStreamQuality(String requested) async {
    final isWifi = await _isWifiNetwork();
    if (isWifi) return requested;
    final q = requested.toLowerCase();
    if (q == 'flac' || q == 'hi_res' || q == 'lossless' || q == 'flac_high') {
      return 'high';
    }
    return requested;
  }

  Future<String?> _preloadLyrics(FeedItem track) async {
    if (!_lyricsEnabled ||
        track.name.isEmpty ||
        (track.artists ?? '').isEmpty) {
      return null;
    }
    preloadingLyrics = true;
    try {
      final result = await sl<BackendService>().rpcCall(
        'getLyricsLRCWithSource',
        {
          'track_name': track.name,
          'artist_name': track.artists ?? '',
          'duration_ms': 0,
        },
      );
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
    return preloadedLyrics;
  }

  Future<void> _preloadVideo(FeedItem track) async {
    if (!_videoEnabled) return;
    preloadingVideo = true;
    try {
      String? videoUrl = _resolveLocalVideoUrl(track);
      videoUrl ??= await downloadVideoToTemp(track);
      preloadedVideoUrl = videoUrl;
      preloadedVideoReady.value = videoUrl;
    } catch (_) {
      preloadedVideoUrl = null;
      preloadedVideoReady.value = null;
    }
    preloadingVideo = false;
  }

  /// Public entry point for the full player's lyrics toggle: fetches the LRC
  /// on demand when the background preload already failed or was skipped.
  /// Returns the fetched lyrics (or null when unavailable / disabled).
  Future<String?> fetchLyricsOnDemand(FeedItem track) async {
    if (!_lyricsEnabled || track.name.isEmpty || (track.artists ?? '').isEmpty) {
      return null;
    }
    if (preloadedLyrics != null && preloadedLyrics!.isNotEmpty) {
      return preloadedLyrics;
    }
    return _preloadLyrics(track);
  }

  /// Returns the stream cache directory, creating it if needed.
  Future<Directory> _getStreamCacheDir() async {
    final appCacheDir = await getApplicationCacheDirectory();
    final dir = Directory(
      '${appCacheDir.path}${Platform.pathSeparator}stream_cache',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Deletes a dead local media file (stream-cache/download file that
  /// media_kit could not decode) so it is never served again and the next
  /// tap re-downloads a fresh copy.
  Future<void> _deleteDeadUriFile(String fileUri) async {
    try {
      if (!fileUri.startsWith('file://')) return;
      final path = Uri.parse(fileUri).toFilePath();
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
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
  /// Providers whose getDownloadUrl serves FULL-LENGTH audio (mirrors the Go
  /// backend's fullStreamProviders). A preloaded stream from one of these is a
  /// complete track, so a tap may reuse it without re-resolving. Providers
  /// outside this set either expose no direct stream at all (apple/amazon/
  /// spotify-web resolve through the download pipeline) or could theoretically
  /// hand back a short preview — for those, the tap still re-resolves with the
  /// download fallback to guarantee the real track.
  static const _fullStreamSources = {
    'ytmusic-spotiflac',
    'youtube',
    'soundcloud',
    'deezer',
    'qobuz-web',
    'tidal-web',
    'ytmusic',
  };

  /// Whether a preload-resolved URL can be reused by a real tap: it must be an
  /// http(s) direct stream resolved from a full-stream source provider.
  bool _canReusePreloadDirectStream(FeedItem track, String url) {
    final src = (track.source ?? '').toLowerCase();
    if (!_fullStreamSources.contains(src)) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Cache key for a track's stream URL: includes the current audio quality so
  /// a quality change never serves a URL resolved at a different tier.
  String _streamCacheKey(String normId) => '$normId|$_audioQuality';

  /// Lazily starts the in-process Go streaming proxy (idempotent) and returns
  /// its base URL, or null when unavailable (desktop without the Go server,
  /// RPC failure). One RPC, cached forever.
  Future<String?> _ensureStreamProxy() {
    if (_streamProxyBase != null) {
      return Future.value(_streamProxyBase);
    }
    return _streamProxyFuture ??= _startStreamProxy();
  }

  Future<String?> _startStreamProxy() async {
    try {
      final res = await sl<BackendService>().rpcCall(
        'startStreamingServer',
        {'port': 0},
        const Duration(seconds: 10),
      );
      final data = _decodeRpcResult(res);
      final base = (data?['url'] ?? '').toString();
      if (base.isNotEmpty && base.startsWith('http://')) {
        _streamProxyBase = base;
        return base;
      }
    } catch (_) {}
    return null;
  }

  /// Rewrites a resolved stream URL for playback: googlevideo URLs go through
  /// the local chunked streaming proxy (see [_ensureStreamProxy]); everything
  /// else (local files, soundcloud/deezer CDN URLs, ...) plays directly.
  Future<String> _localProxyUrl(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return url;
    }
    try {
      final host = Uri.parse(url).host.toLowerCase();
      if (!host.endsWith('googlevideo.com')) return url;
    } catch (_) {
      return url;
    }
    final base = await _ensureStreamProxy();
    if (base == null || base.isEmpty) return url;
    return '$base/stream?url=${Uri.encodeComponent(url)}';
  }

  /// Builds the HTTP headers mpv must send when opening [url] — mirrors what
  /// ArchiveTune's OkHttp interceptor does for YouTube media. googlevideo URLs
  /// carry a `c` (client) param; YouTube 403s requests whose User-Agent does
  /// not match that client, and web/TV clients additionally require an
  /// Origin/Referer. Without these headers every resolved YouTube stream dies
  /// at open with "HTTP error 403 Forbidden" and the player sits at 00:00.
  Map<String, String>? _headersForUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      final isYoutube = host.endsWith('googlevideo.com') ||
          host.endsWith('youtube.com') ||
          host.endsWith('ytimg.com');
      if (!isYoutube) return null;

      final c = (uri.queryParameters['c'] ?? '').toUpperCase();
      String ua;
      String? origin;
      String? referer;
      if (c.startsWith('ANDROID_VR') || c == 'ANDROID') {
        ua = c.startsWith('ANDROID_VR')
            ? 'com.google.android.apps.youtube.vr.oculus/1.65.10 '
                  '(Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip'
            : 'com.google.android.youtube/20.02.30 (Linux; U; Android 11) '
                  'gzip';
      } else if (c == 'IOS' || c.startsWith('IOS')) {
        ua = 'com.google.ios.youtube/21.02.3 (iPhone16,2; U; CPU iOS 18_3_2 '
              'like Mac OS X)';
      } else if (c == 'MWEB') {
        ua = 'Mozilla/5.0 (iPad; CPU OS 16_7_10 like Mac OS X) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/'
              '15E148 Safari/604.1,gzip(gfe)';
        origin = 'https://www.youtube.com';
        referer = 'https://www.youtube.com/';
      } else if (c == 'WEB_REMIX') {
        ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
        origin = 'https://music.youtube.com';
        referer = 'https://music.youtube.com/';
      } else if (c == 'WEB_EMBEDDED_PLAYER' || c == 'WEB') {
        ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
        origin = 'https://www.youtube.com';
        referer = 'https://www.youtube.com/';
      } else if (c == 'TVHTML5' || c == 'TVHTML5_SIMPLY_EMBEDDED_PLAYER') {
        ua = c == 'TVHTML5'
            ? 'Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.5) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Version/6.5 TV Safari/537.36'
            : 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version';
        origin = 'https://www.youtube.com';
        referer = 'https://www.youtube.com/tv';
      } else {
        ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
      }
      return {
        'User-Agent': ua,
        if (origin != null) 'Origin': origin,
        if (referer != null) 'Referer': referer,
      };
    } catch (_) {
      return null;
    }
  }

  /// Cheap liveness probe for a cached http(s) stream URL. Cached URLs can
  /// silently rot and mpv reports those open failures WITHOUT any Dart-visible
  /// error — the player just sits at 00:00.
  ///
  /// GATE DETECTION: YouTube bot-gates some formats (itag=251 audio-only opus)
  /// on flagged egress IPs by serving only the FIRST ~1MB of the file and
  /// answering 403 for any range at/past that point — while the same video's
  /// itag=18 serves the whole file. A probe near the start (bytes=0-0) sees
  /// 206 on those gated URLs and reports them alive, so the dead format wins
  /// cache reuse and playback stalls mid-file. Probing the LAST byte of the
  /// file (clen-1 from the URL) distinguishes them: gated URLs answer 403,
  /// healthy files answer 206. 416 = the requested byte is past EOF, which
  /// only happens when the whole file is under the probed offset (the gate
  /// never applies) — counted alive. Only consulted on cache reuse for an
  /// actual tap (never on fresh resolutions — those were already probed by
  /// the backend) so healthy URLs pay ~one round trip.
  Future<bool> _streamUrlAlive(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return true;
    }
    try {
      final m = RegExp(r'[?&]clen=(\d+)').firstMatch(url);
      final probeEnd = (m != null && int.parse(m.group(1)!) > 0)
          ? (int.parse(m.group(1)!) - 1).toString()
          : '3145727'; // ~3MB: past every observed gate when clen is missing
      final res = await http
          .get(
            Uri.parse(url),
            headers: {
              // A byte at the end of the file: gated URLs 403 here, healthy
              // ones 206 (a short file answers 416 — the gate never applies).
              'Range': 'bytes=$probeEnd-$probeEnd',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/131.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 4));
      final code = res.statusCode;
      // STRICT: only a confirmed 200/206/416 means the CDN will serve this
      // URL's full content. A dead URL can surface as 403/404/410 OR as a
      // network-level failure (timeout/abort/redirect chain) — both must
      // count as dead, otherwise the dead URL wins and the player freezes at
      // 00:00 with no error. The cost of a false negative is one
      // re-resolution (which now probes and falls back to a serving format),
      // far cheaper than a silent stall.
      return code == 200 || code == 206 || code == 416;
    } catch (_) {
      return false;
    }
  }

  /// Computes a stream URL's expiry: local files never expire; YouTube
  /// googlevideo URLs carry an exact unix-seconds `expire` param; everything
  /// else gets a conservative default TTL.
  DateTime? _expiryForUrl(String url) {
    if (url.startsWith('file://')) return null;
    final m = RegExp(r'[?&]expire=(\d{10})').firstMatch(url);
    if (m != null) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(m.group(1)!) * 1000);
    }
    return DateTime.now().add(_defaultStreamTtl);
  }

  /// A cached URL within [_urlExpirySafety] of its expiry is stale — re-resolve.
  bool _streamUrlStale(_CachedStream? cached) {
    final exp = cached?.expiresAt;
    if (exp == null) return false;
    return DateTime.now().add(_urlExpirySafety).isAfter(exp);
  }

  ///
  /// [withFallback] lets a background prefetch request the FULL resolution
  /// pipeline (download fallback included) instead of the cheap direct-stream
  /// probe. It is used for exactly one track — the immediate next in a
  /// sequential queue on WiFi — so advancing the queue starts instantly even
  /// for DRM/preview providers that have no direct stream (Tidal/Amazon/…).
  /// If [track] was already being prefetched (in-flight future), the same
  /// future is awaited so playback serves whatever is already resolved instead
  /// of starting the resolution from scratch.
  Future<String?> _resolveStreamUrl(
    FeedItem track, {
    bool isPreload = false,
    bool withFallback = false,
  }) async {
    final normKey = normalizeTrackId(track.id);
    final key = _streamCacheKey(normKey);
    // A full-fallback resolution (real tap OR full preload) may reuse any
    // cached result that itself came from a fallback-capable resolution. A
    // plain preload may reuse any cached URL.
    final wantsFallback = !isPreload || withFallback;
    final cached = _streamUrlCache[key];
    // A preload may reuse any cached URL. A real tap reuses a cached result
    // when it came from the download pipeline (file://, withFallback) OR when
    // the preload resolved a direct http(s) stream from a FULL-STREAM source
    // (ytmusic/soundcloud/deezer/youtube serve complete tracks — a preview is
    // never returned, so re-resolving would just re-hit every provider and
    // re-wait). A stream that already failed to decode forces re-resolution.
    if (cached != null &&
        !_streamUrlStale(cached) &&
        (isPreload ||
            cached.withFallback ||
            (_canReusePreloadDirectStream(track, cached.url) &&
                _brokenUrlByTrack[normKey] != cached.url))) {
      // A REAL tap about to reuse a cached URL must make sure the URL still
      // serves. Cached URLs rot silently (YouTube 403s one format while
      // others serve, DRM endpoints expire) and mpv fails those opens with no
      // Dart-visible error — the player would sit at 00:00 forever with the
      // dead URL winning every re-tap. Probe first; when dead, drop the cache
      // entry and fall through to a fresh resolution (which runs the backend's
      // client/format probe chain and picks a serving format). Preloads skip
      // the probe (no user waiting); playback starts after the download
      // pipeline validates anyway.
      if (isPreload || await _streamUrlAlive(cached.url)) {
        return cached.url;
      }
      debugPrint(
        '[Player] Cached stream dead (${cached.url.length > 120 ? cached.url.substring(0, 120) : cached.url}) — re-resolving $normKey',
      );
      _streamUrlCache.remove(key);
      _brokenUrlByTrack[normKey] = cached.url;
    }
    final inFlight = _streamFutures[key];
    if (inFlight != null) {
      // A probe-only resolution (no download fallback) is in flight but the
      // caller wants the full pipeline (real tap OR full preload) — start a
      // fresh resolution WITH the fallback instead of awaiting the probe.
      if (wantsFallback && !inFlight.$2) {
        _streamFutures.remove(key);
      } else {
        return inFlight.$1;
      }
    }

    final future =
        _resolveStreamUrlInner(track, isPreload: isPreload, withFallback: withFallback);
    _streamFutures[key] = (future, wantsFallback);
    try {
      final url = await future;
      if (url != null && url.isNotEmpty) {
        // Taps and full preloads resolve through the download pipeline
        // (withFallback=true); background probe preloads only probe direct
        // streams (withFallback=false). Never let a late-finishing preload
        // downgrade a better entry that a tap already stored (both can be in
        // flight for the same track).
        final current = _streamUrlCache[key];
        if (current == null || !isPreload || !current.withFallback) {
          _streamUrlCache[key] =
              _CachedStream(url, wantsFallback, _expiryForUrl(url));
        }
        _markReady(normKey);
        // Persist to disk cache (fire-and-forget)
        unawaited(_savePersistentStreamCache());
        return url;
      }
      // A real tap that could not produce a download-quality copy still has
      // the preload's direct stream URL as plan B — better than silence.
      // Skip it if that probe URL already failed to decode on a prior open.
      if (!isPreload && cached != null && !cached.withFallback) {
        if (_brokenUrlByTrack[normKey] != cached.url) return cached.url;
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

  Future<String?> _resolveStreamUrlInner(
    FeedItem track, {
    bool isPreload = false,
    bool withFallback = false,
  }) async {
    final name = track.name.trim();
    if (name.isEmpty) return null;
    try {
      final result = await sl<BackendService>().rpcCall('getStreamPackage', {
        'preferredProvider': track.source ?? '',
        'trackID': track.id,
        'quality': await _effectiveStreamQuality(_audioQuality),
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
        // Background probe preloads skip the download fallback (no full audio
        // downloads in the background); real taps and the one-track full
        // preload (immediate next on WiFi) allow it.
        'allowFallback': !isPreload || withFallback,
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
          _lastStreamError = err;
          _lastStreamErrorType = (data['errorType'] ?? '').toString();
          _lastStreamService = (data['service'] ?? '').toString();
        }
      }
      return null;
    } catch (e) {
      if (!isPreload) {
        _lastStreamError = e.toString();
      }
      return null;
    }
  }

  /// Decrypts an encrypted/DRM stream file returned by the backend via
  /// ffmpeg-kit, writing the playable file into the stream cache, and returns a
  /// `file://` URL for it (or null on failure).
  Future<String?> _decryptForPlayback(
    Map<String, dynamic> data,
    FeedItem track,
  ) async {
    final src = (data['filePath'] ?? '').toString();
    final key = (data['decryptionKey'] ?? '').toString();
    if (src.isEmpty || key.isEmpty) return null;

    final normalized = normalizeTrackId(track.id);
    final cacheDir = await _getStreamCacheDir();
    final result = await decryptMovKeyFile(
      srcPath: src,
      key: key,
      inputFormat: (data['inputFormat'] ?? '').toString(),
      outputExtension: (data['outputExtension'] ?? '').toString(),
      outputDir: cacheDir.path,
      outputBaseName: normalized,
    );
    if (result.success && result.filePath != null) {
      _tempStreamFiles.add(normalized);
      return 'file://${result.filePath!.replaceAll('\\', '/')}';
    }
    // debug removed
    return null;
  }

  /// Pre-resolves stream URLs for an observed context (e.g. the visible feed)
  /// so the first track the user taps plays instantly. Fire-and-forget, capped
  /// to [limit] tracks, honoring the preload profile and skipping any track
  /// already local or already cached/in-flight.
  void precacheContext(List<FeedItem> tracks, {int? limit}) async {
    final profile = sl<ValueNotifier<PerformanceProfile>>().value;
    if (!profile.preloadEnabled) return;
    // Skip feed preload on mobile data to save bandwidth — the user hasn't
    // tapped anything yet, so this is purely speculative. Only preload on
    // WiFi/ethernet where data is unlimited.
    if (!await _isWifiNetwork()) return;
    // Bound by the device profile: a 4GB phone (medium) preloads 2 tracks, a
    // desktop-class device (high) 4. Screens pass a higher cap only when they
    // know their content is stable (album/playlist once loaded); unbounded
    // defaults here would fire 10+ stream resolutions that keep the backend
    // bridge busy while the user searches.
    var cap = limit ?? profile.preloadTracks;
    if (cap < 1) return;
    var added = 0;
    for (final track in tracks) {
      if (added >= cap) break;
      if (track.type != 'track') continue;
      if (track.name.trim().isEmpty) continue;
      final key = _streamCacheKey(normalizeTrackId(track.id));
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
    final n = profile.preloadTracks;

    if (qState.shuffle && qState.tracks.length > 1) {
      // Shuffle: next/previous pick RANDOM tracks, so preloading sequential
      // neighbors is wasted work. Preload a few random candidates instead so
      // whichever random track actually plays next is likely already resolved.
      // Only preload on WiFi to save mobile data — speculative shuffles are
      // low priority.
      if (await _isWifiNetwork()) {
        var picked = 0;
        var guard = 0;
        while (picked < n && guard < qState.tracks.length * 4) {
          guard++;
          final track = qState.tracks[Random().nextInt(qState.tracks.length)];
          if (normalizeTrackId(track.id) == currentKey) continue;
          if (toPreload.add(track)) picked++;
        }
      }
    } else {
      // Sequential: preload the upcoming and previous tracks in queue order.
      // Only preload on WiFi — the immediate next track is handled separately
      // with withFallback:true for crossfade (runs on any network).
      if (await _isWifiNetwork()) {
        for (int i = 1; i <= n; i++) {
          final idx = qState.currentIndex + i;
          if (idx >= qState.tracks.length) break;
          toPreload.add(qState.tracks[idx]);
        }
        for (int i = 1; i <= n; i++) {
          final idx = qState.currentIndex - i;
          if (idx < 0) break;
          toPreload.add(qState.tracks[idx]);
        }
      }
    }

    for (final track in toPreload) {
      final normId = normalizeTrackId(track.id);
      if (normId == currentKey) continue;
      if (_streamUrlCache.containsKey(_streamCacheKey(normId))) continue;
      if (_resolveLocalUri(track) != null) continue;
      _schedulePrefetch(track);
    }

    // Full preload of the immediate next track: sequential listening will play
    // it next with near-certainty, so resolve it through the WHOLE pipeline
    // (download fallback included) — when the user hits next, it is already
    // downloaded/resolved and starts instantly, even for DRM/preview providers
    // that have no direct stream. Runs on ANY network (not just WiFi) because
    // the silence gap between tracks is the #1 UX complaint. The probe loop
    // above runs first: if the cheap probe already produced a usable direct
    // stream, this full resolution just reuses it and no download happens.
    if (!qState.shuffle && qState.tracks.isNotEmpty) {
      final nextIdx = qState.currentIndex + 1;
      if (nextIdx < qState.tracks.length) {
        final next = qState.tracks[nextIdx];
        final normId = normalizeTrackId(next.id);
        if (normId != currentKey && _resolveLocalUri(next) == null) {
          final cachedNext = _streamUrlCache[_streamCacheKey(normId)];
          if (cachedNext == null ||
              !cachedNext.withFallback ||
              _streamUrlStale(cachedNext)) {
            _schedulePrefetch(next, withFallback: true);
          }
        }
      }
    }
  }

  /// Called when the crossfade starts fading out. Immediately kicks off a
  /// full resolution (with download fallback) for the next track so it's
  /// ready to play the instant the current track completes. Unlike the
  /// regular preload which may defer to WiFi, this runs on any network
  /// because the crossfade is already happening — a few KB/s of resolution
  /// traffic is worth eliminating the silence gap.
  void _eagerPreloadNext() {
    final qState = _queueCubit.state;
    if (!qState.hasCurrent || qState.shuffle) return;
    final nextIdx = qState.currentIndex + 1;
    if (nextIdx >= qState.tracks.length) return;
    final next = qState.tracks[nextIdx];
    final normId = normalizeTrackId(next.id);
    final currentKey = normalizeTrackId(qState.current!.id);
    if (normId == currentKey) return;
    if (_resolveLocalUri(next) != null) return; // already local
    final cached = _streamUrlCache[_streamCacheKey(normId)];
    if (cached != null && cached.withFallback && !_streamUrlStale(cached)) return; // already resolved
    _schedulePrefetch(next, withFallback: true);
  }

  /// Resolves a local video file path for [track], or null if not found.
  String? _resolveLocalVideoUrl(FeedItem track) {
    if (_downloadPath == null) return null;
    final videoExts = ['mp4', 'webm', 'mkv', 'avi'];
    for (final ext in videoExts) {
      final path = '$_downloadPath\\${track.id}.$ext';
      if (File(path).existsSync()) {
        return 'file://${path.replaceAll('\\', '/')}';
      }
    }
    if ((track.name.isNotEmpty &&
        track.artists != null &&
        track.artists!.isNotEmpty)) {
      const invalid = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
      String sanitize(String s) {
        var r = s;
        for (final ch in invalid) {
          r = r.replaceAll(ch, '_');
        }
        r = r.replaceAll(RegExp(r'[. ]+$'), '');
        return r.isEmpty ? 'unknown' : r;
      }

      final stem = '${sanitize(track.artists!)} - ${sanitize(track.name)}';
      for (final ext in videoExts) {
        final path = '$_downloadPath\\$stem.$ext';
        if (File(path).existsSync()) {
          return 'file://${path.replaceAll('\\', '/')}';
        }
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
      final cacheDir = Directory(
        '${appCacheDir.path}${Platform.pathSeparator}stream_cache',
      );
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
      final res = await sl<BackendService>().downloadByStrategy(
        jsonEncode(strategy),
      );
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

    // 1.5 Cross-source match by name-fingerprint (same song, any provider).
    // Indexed in _loadLocalFiles for each history row, so a track downloaded
    // from deezer/amazon plays locally even when selected from a soundcloud/
    // spotify feed whose ids differ.
    if (track.name.isNotEmpty) {
      final fp = fingerprintFromName(track.name, track.artists ?? '');
      final localPath = _localFiles[fp];
      if (localPath != null && File(localPath).existsSync()) {
        return 'file://${localPath.replaceAll('\\', '/')}';
      }
    }

    // 1.75 Cross-source match by ISRC — the canonical recording identifier
    // that all providers share, so a track downloaded under one provider
    // plays locally even when name/artist differ on the provider the user is
    // browsing right now.
    final trackIsrc = (track.isrc ?? '').trim();
    if (trackIsrc.isNotEmpty) {
      final localPath = _localFiles[fingerprintIsrc(trackIsrc)];
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
            final fname =
                f.path.split(Platform.pathSeparator).last.toLowerCase();
            if (idLower.any((id) => fname.startsWith(id))) {
              return 'file://${f.path.replaceAll('\\', '/')}';
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Smoothly transitions volume from [from] to [to] over [duration].
  Future<void> _fadeVolume(double to, Duration duration) async {
    if (isClosed) return;
    const steps = 20;
    final stepMs = duration.inMilliseconds ~/ steps;
    final currentVol = state.volume;
    for (var i = 1; i <= steps; i++) {
      if (isClosed) return;
      final v = currentVol + (to - currentVol) * (i / steps);
      _player.setVolume(v.clamp(0, 100));
      emit(state.copyWith(volume: v.clamp(0, 100)));
      await Future.delayed(Duration(milliseconds: stepMs));
    }
  }

  Future<void> _onTrackCompleted() async {
    if (isClosed) return;

    // Reset crossfade state for the next track.
    _crossfadingOut = false;

    // A `completed` event that arrived after a newer open started belongs to
    // the media that open disposed (or a stale race), not to a real end of
    // file — advancing here is what makes the queue "skip 2 by 2" and change
    // tracks at any random second.
    if (_openGeneration != _openedAtGeneration) return;

    // media_kit can emit a spurious `completed` notification right after open()
    // (e.g. the decrypted local FLACs), often BEFORE the real duration is parsed
    // (duration still 0). Only advance when we have a real end-of-file: a known
    // duration (>0) with position at/near the end. If duration is still unknown,
    // treat it as premature — live/radio never send `completed` anyway, so this
    // cannot get stuck, and opens with missing duration must not skip to next.
    final durMs = state.duration.inMilliseconds;
    final posMs = state.position.inMilliseconds;
    final completedTrack = _queueCubit.state.current;
    final fromHttp = _lastOpenedUri?.startsWith('http://') == true ||
        _lastOpenedUri?.startsWith('https://') == true;

    // ── Guard dead/truncated-stream EOF ─────────────────────────────────
    // A completion with a REAL parsed duration (>0) but that died before
    // delivering meaningful audio means the media was dead — e.g. the local
    // streaming proxy served an empty/dead response for an expired URL, or a
    // 403 became a silent EOF in mpv, or the proxy pipe broke after the first
    // chunk so the stream "completed" after only ~10% of its duration. This is
    // NOT an end of file: leaving it here puts the player in a phantom
    // paused/playing limbo on the dead URL (the "se pausa sola y no reproduce
    // nada" bug) that only clears when a background download happens to finish
    // — which can take 30s+ of silence. Re-resolve the SAME track once through
    // the download pipeline (which validates the result) instead. If the
    // re-resolved track dies the same way, it is genuinely unplayable right
    // now — fall through and advance past it.
    final deadStreamEof =
        completedTrack != null && fromHttp && durMs > 0 && posMs <= durMs * 0.10;
    if (deadStreamEof) {
      final normId = normalizeTrackId(completedTrack.id);
      if (_deadStreamRecovered.add(normId)) {
        debugPrint(
          '[Player] Dead-stream EOF (pos=$posMs, dur=$durMs) for $normId — '
          're-resolving via download fallback.',
        );
        _streamUrlCache.remove(_streamCacheKey(normId));
        _streamFutures.remove(_streamCacheKey(normId));
        _brokenUrlByTrack[normId] = _lastOpenedUri ?? '';
        unawaited(_openTrack(completedTrack));
        return;
      }
    } else if (durMs <= 0 || posMs < durMs - 1500) {
      return;
    }

    // ── Guard anti-preview ───────────────────────────────────────────────
    // A direct http stream that ends FAR short of the track's real duration is
    // almost certainly a preview/clip served by the source (entitlement or a
    // mirror returning 30s). Advancing the queue on that fake completion would
    // silently skip the real song — instead, re-open the SAME track once via
    // the download fallback, which validates full length before accepting a
    // file. Only applies to real EOFs of http streams whose track metadata has
    // a known duration; local produced files never trigger it.
    final expectedMs = completedTrack?.durationMs ?? 0;
    final playedMs = state.duration.inMilliseconds;
    if (completedTrack != null &&
        fromHttp &&
        expectedMs >= 60000 &&
        playedMs > 0 &&
        playedMs <= expectedMs * 0.55) {
      final normId = normalizeTrackId(completedTrack.id);
      if (_previewRecoveredTracks.add(normId)) {
        debugPrint('[Player] Short stream for $normId: played $playedMs ms of '
            'expected $expectedMs ms — re-resolving via download fallback.');
        // Forget the cached direct URL (and any in-flight resolution) so the
        // re-open goes through the download pipeline, which rejects
        // preview-length sources.
        _streamUrlCache.remove(_streamCacheKey(normId));
        _streamFutures.remove(_streamCacheKey(normId));
        _brokenUrlByTrack[normId] = _lastOpenedUri!;
        unawaited(_openTrack(completedTrack));
        return; // do NOT advance the queue on the clip's fake completion
      }
    }

    // Registrar play en el historial local (Drift) antes de avanzar la cola.
    if (completedTrack != null && _playbackCache != null) {
      final trackId = normalizeTrackId(completedTrack.id);
      final durMs = state.duration.inMilliseconds;
      unawaited(
        _playbackCache!.logPlay(
          trackId: trackId,
          trackName: completedTrack.name,
          artistName: completedTrack.artists ?? '',
          albumName: completedTrack.albumName,
          durationMs: durMs > 0 ? durMs : null,
          percentage: 100,
        ),
      );
    }

    if (completedTrack != null) {
      final scrobble = ScrobbleService();
      if (scrobble.hasLastfm || scrobble.hasListenBrainz) {
        unawaited(
          scrobble.scrobble(
            artist: completedTrack.artists ?? '',
            track: completedTrack.name,
            timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            album: completedTrack.albumName,
            duration: state.duration.inMilliseconds ~/ 1000,
          ),
        );
      }
    }

    final completedTrackId = _normalizeCurrentId();      if (completedTrackId != null) {
      if (_streamedTrackIds.remove(completedTrackId)) {
        unawaited(_cleanupStreamCache(completedTrackId));
      }
      unawaited(_cleanupTempFile(completedTrackId));
    }

    // The advance is about to emit (possibly the SAME index for repeat-one):
    // mark it so _listenQueue reopens instead of skipping the same track.
    _forceReopen = true;
    final hadNext = _queueCubit.next();

    // Crossfade: fade in the volume for the next track.
    if (_crossfadeEnabled) {
      _fadeVolume(state.volume, _crossfadeDuration);
    }
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
  void removeLocalFilesProviderIds(
    List<String> providerIds, {
    bool deleteFiles = false,
  }) {
    final wanted = providerIds.toSet();
    if (wanted.isEmpty) return;

    final pathsToRemove = <String>{};
    for (final id in providerIds) {
      final path = _localFiles.remove(id);
      if (path != null) pathsToRemove.add(path);
    }
    if (pathsToRemove.isNotEmpty) {
      _localFiles.removeWhere((_, v) => pathsToRemove.contains(v));
    }

    if (deleteFiles) {
      // Respaldo a disco: si el mapa en memoria aún no indexó un archivo (app
      // recién abierta / TTL no refrescado), se resuelven los stems directamente
      // escaneando el directorio de descargas, para que ningún audio quede
      // huérfano en disco tras el borrado aunque la caché esté vacía.
      for (final path in _downloadFilesMatching(wanted)) {
        if (pathsToRemove.add(path)) {
          _localFiles.removeWhere((_, v) => v == path);
        }
      }
      for (final path in pathsToRemove) {
        _deleteLocalFile(path);
      }
    }
  }

  /// Escanea una vez el directorio de descargas y devuelve las rutas de los
  /// archivos cuyo nombre (sin extensión) coincide con alguno de [stems].
  Set<String> _downloadFilesMatching(Set<String> stems) {
    final out = <String>{};
    final dirPath = _downloadPath;
    if (dirPath == null) return out;
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return out;
      for (final f in dir.listSync(followLinks: false)) {
        if (f is! File) continue;
        final stem = _fileStem(f.path);
        if (stems.contains(stem)) {
          out.add(f.path);
          continue;
        }
        // Los descargas se guardan como "{id}_audio" y tras el decrypt pueden
        // quedar "{id}_audio.dec". El borrado sólo recibe el id base, así que
        // también matchean prefix con frontera "_" o "." (evita {id}Otro).
        for (final w in stems) {
          if (stem.startsWith('${w}_') || stem.startsWith('$w.')) {
            out.add(f.path);
            break;
          }
        }
      }
    } catch (_) {}
    return out;
  }

  /// Nombre de archivo sin extension (stem).
  String _fileStem(String path) => path
      .split(Platform.pathSeparator)
      .last
      .replaceAll(RegExp(r'\.[^.]+$'), '');

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
      // Params planos con las keys que espera Go (trackTitle/artistName/limit).
      // Antes se enviaban anidados en 'request' con keys snake_case, así que el
      // backend recibía título/artista vacíos y el autoplay buscaba "" en todos
      // los providers (se veía en el log como "Searching Apple Music: ").
      final json = await backend.rpcCall('getSimilarTracks', {
        'trackTitle': lastTrack.name,
        'artistName': lastTrack.artists,
        'limit': 10,
      });
      if (json == null || json == '' || json == '[]') return;

      final list = jsonDecode(json.toString()) as List;
      if (list.isEmpty) return;

      final similarTracks =
          list.map((e) {
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
      await _player.seek(
        Duration(
          milliseconds: (dur.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
        ),
      );
    }
  }

  void next() => _queueCubit.next();

  void previous() => _queueCubit.previous();

  void setVolume(double vol) {
    // App state keeps volume in 0.0–1.0, but media_kit's setVolume forwards
    // the value straight to mpv's `volume` property, which is 0–100 (default
    // 100). Without the ×100 the app was playing at ~1% volume — technically
    // "playing" (position advances, mixer active) but essentially inaudible.
    final v = vol.clamp(0.0, 1.0);
    _player.setVolume(v * 100);
    emit(state.copyWith(volume: v));
  }

  /// Soft fade-in used right after every [_player.open]: ramps from silence to
  /// the user's volume over ~110ms. Kept tiny on purpose — long crossfades over
  /// the local↔stream switching logic risk audible gaps and added start
  /// latency. If this ever needs to become a true overlap crossfade, it needs
  /// a second Player + its own queue-sync (device-tested); see Fase-4 notes.
  Future<void> _fadeInAudio() async {
    final target = state.volume.clamp(0.0, 1.0);
    if (target <= 0.001) return;
    const steps = 8;
    // Convert the 0–1 fade target to media_kit/mpv's 0–100 volume scale,
    // otherwise the fade ends at mpv volume=1 (1%) and playback is inaudible.
    final target100 = target * 100;
    try {
      for (var i = 1; i <= steps; i++) {
        await _player.setVolume(target100 * i / steps);
        await Future<void>.delayed(const Duration(milliseconds: 14));
      }
      await _player.setVolume(target100);
    } catch (_) {
      // Never let a cosmetic fade fail playback.
    }
  }

  void setRate(double rate) {
    final r = rate.clamp(0.5, 2.0);
    if (r == 1.0) {
      _player.setRate(1.0);
    } else {
      _player.setRate(r);
    }
    emit(state.copyWith(rate: r));
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
    preloadedVideoReady.dispose();
    await _player.dispose();
    return super.close();
  }
}
