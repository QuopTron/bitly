export '../cache/download_state.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import '../rpc/backend_service.dart';
import '../../frontend/shared/models/download_settings.dart';
import '../../frontend/shared/models/feed_models.dart';
import '../../frontend/shared/utils/download_strategy.dart';
import '../../injection.dart';
import '../cache/settings_cache.dart';
import '../cache/download_cache.dart';
import 'item_fingerprint.dart';
import 'verification_service.dart';
import '../cache/download_state.dart';
import '../cache/library_cache.dart';
import 'player_cubit.dart';
import 'like_cubit.dart';

final _log = Logger();

/// Stores original batch track data so failed tracks can be retried later.
class _BatchData {
  final List<Map<String, dynamic>> tracks;
  final DownloadSettings settings;
  final String source;
  final String? qualityOverride;
  const _BatchData(this.tracks, this.settings, this.source, [this.qualityOverride]);
}

/// Persistent metadata for a downloaded track (survives restart via DB).
class _TrackInfo {
  final String trackId;
  final String name;
  final String? artist;
  final String? coverUrl;
  final String? coverPath;
  final String source;
  const _TrackInfo(this.trackId, this.name, this.artist, this.coverUrl, this.source, [this.coverPath]);
}

class _BatchMeta {
  final String name;
  final String itemType;
  final String itemId;
  final String source;
  const _BatchMeta(this.name, this.itemType, this.itemId, this.source);
}

class DownloadCubit extends Cubit<DownloadCubitState> {
  final BackendService _backend;
  final DownloadCache _downloadCache;
  Timer? _progressTimer;
  Timer? _historyTimer;
  /// Tracks when each download was started (for timeout detection).
  final Map<String, DateTime> _startedAt = {};
  /// Count of consecutive poll cycles where backend returned empty progress
  /// while we have in-progress items. Used to detect backend restart.
  int _emptyProgressStreak = 0;
  /// Whether we already verified backend health for the current streak.
  /// Set to true on the first cycle where streak >= 4, to avoid repeated
  /// health checks on every subsequent poll cycle.

  /// Maps batch key (e.g. "album_123_spotify") → list of audio track IDs
  /// so aggregate progress can be computed from individual track states.
  final Map<String, List<String>> _batchTrackIds = {};
  /// Stores original batch track data for retry of failed tracks.
  /// Key: batchKey (e.g. "album_123_spotify"), Value: original track maps + metadata.
  /// Persists after batch completes so retry is possible later.
  final Map<String, _BatchData> _batchData = {};
  /// Key: "track_{id}_{source}" → metadata, populated from DB and batch data.
  final Map<String, _TrackInfo> _trackMeta = {};
  /// Set of normalized track IDs that already exist in download history.
  /// Used to skip re-downloading tracks during batch album/playlist downloads.
  final Set<String> _downloadedTrackIds = {};
  /// Key: batchKey → metadata for batch (album/playlist), populated from DB.
  final Map<String, _BatchMeta> _batchMeta = {};
  /// Maps Go backend [item_id] → state key (e.g. "deezer:3171003131" → "track_3171003131_deezer").
  /// Used in [_pollProgress] to translate Go progress entries to local state keys.
  final Map<String, String> _itemIdToStateKey = {};
  /// Raw Go item IDs whose encrypted/DRM download was already handled by
  /// client-side decryption (ffmpeg-kit). Prevents reprocessing the same
  /// completed tracker entry on later polls.
  final Set<String> _clientDecryptDone = {};

  /// Non-null when a decrypt-failure snackbar is pending (shown once, cleared
  /// by [acknowledgeDecryptError]).
  String? _pendingDecryptError;
  /// Prevents concurrent verification flows triggered by _pollProgress.
  bool _verificationInProgress = false;
  /// Prevents overlapping polls: ffmpeg-kit decryption can outlast the 3s
  /// polling timer, and concurrent polls would race on the same file.
  bool _pollingInProgress = false;
  /// True once the startup repair of broken (encrypted) downloads has been run,
  /// so the scan only executes once per app session.
  bool _repairAttempted = false;

  /// Maps extension IDs to user-friendly display names.
  static const Map<String, String> _providerDisplayNames = {
    'deezer': 'Deezer',
    'qobuz-web': 'Qobuz',
    'tidal-web': 'Tidal',
    'amazon': 'Amazon Music',
    'apple-music': 'Apple Music',
    'soundcloud': 'SoundCloud',
    'pandora': 'Pandora',
  };

  String _userId = '';
  /// Timestamp ISO 8601 de la última carga de batches.
  /// Pasado como 'since' a getDownloadedBatches para delta loading.
  String? _lastBatchesTimestamp;



  DownloadCubit(this._backend)
      : _downloadCache = sl<DownloadCache>(),
        super(const DownloadCubitState());

  @override
  Future<void> close() {
    _progressTimer?.cancel();
    _historyTimer?.cancel();
    return super.close();
  }

  Future<void> initialize() async {
    emit(state.copyWith(loading: true));
    try {
      await _loadUserId();
      await _loadHistory();
    } catch (_) {}
    emit(state.copyWith(loading: false));
    _startPolling();
    _startHistoryRefresh();
    // One-time startup repair: detect downloads that aren't playable audio
    // (encrypted files saved before the ffmpeg-kit decrypt fix) and re-download
    // them automatically. Runs async so it never blocks the home screen.
    unawaited(_repairBrokenDownloads());
  }

  Future<void> _loadUserId() async {
    try {
      final setup = await sl<SettingsCache>().loadSetupData();
      _userId = setup?.username ?? '';
    } catch (_) {
      _userId = '';
    }
  }

  /// Loads [getDownloadHistory] and [getDownloadedBatches] into state.
  ///
  /// En lugar de capturar un snapshot de [state.downloads] al inicio (lo que
  /// causa race conditions con [_pollProgress]), construye un map de items
  /// completados desde el historial y los mergea en el estado actual justo
  /// antes de emitir. Esto evita perder actualizaciones concurrentes.
  ///
  /// Además normaliza [providerTrackId] al leer de la DB para que las keys
  /// coincidan con las usadas por [startAlbumDownload] y [startPlaylistDownload]
  /// (que normalizan internamente).
  Future<void> _loadHistory() async {
    final fps = Set<String>.from(state.downloadedFingerprints);
    // Solo recolectamos los items completados, NO capturamos state.downloads
    final completedItems = <String, DownloadStateData>{};
    bool changed = false;

    // ── 1. Restaurar tracks individuales desde download_history ───────
      final historyJson = await _downloadCache.getDownloadHistory();
    if (historyJson.isNotEmpty && historyJson != '[]') {
      final list = jsonDecode(historyJson) as List;
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final trackName = (m['track_name'] ?? m['trackName'] ?? '') as String;
        final artistName = (m['artist_name'] ?? m['artistName'] ?? '') as String;
        if (trackName.isNotEmpty) {
          fps.add(fingerprintFromName(trackName, artistName));
        }
        var src = (m['providerSource'] ?? m['service'] ?? '') as String;
        if (src.isEmpty) src = 'download';
        final rawId = (m['id'] ?? m['providerTrackId'] ?? '') as String;
        if (rawId.isNotEmpty) {
          // Normalizar el providerTrackId para que coincida con las keys
          // usadas por startAlbumDownload / startPlaylistDownload.
          final normalizedId = normalizeTrackId(rawId);
          _downloadedTrackIds.add(normalizedId);
          final key = 'track_${normalizedId}_$src';
          completedItems[key] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
          changed = true;
          final coverUrl = (m['cover_url'] ?? m['coverUrl'] ?? '') as String;
          final coverPath = (m['cover_path'] ?? m['coverPath'] ?? '') as String;
          // Don't overwrite a good in-memory entry with null covers from DB
          // (e.g. tracks downloaded in this session have valid covers, but
          // old DB entries may have null cover_url because the fallback chain
          // was incomplete at time of download).
          final existing = _trackMeta[key];
          final existingHasCover = existing?.coverUrl?.isNotEmpty == true || existing?.coverPath?.isNotEmpty == true;
          if (!existingHasCover) {
            _trackMeta[key] = _TrackInfo(
              normalizedId, trackName, artistName.isNotEmpty ? artistName : null,
              coverUrl.isNotEmpty ? coverUrl : null, src,
              coverPath.isNotEmpty ? coverPath : null,
            );
          }
        }
      }
    }

    // ── 2. Restaurar batches (albums/playlists) desde downloaded_batches ─
    final batchesJson = await _downloadCache.getDownloadedBatches(
      since: _lastBatchesTimestamp,
    );
    // Map from normalized track ID → batchKey (for cover backfill)
    final batchTrackMap = <String, String>{};
    if (batchesJson.isNotEmpty && batchesJson != '[]') {
      final list = jsonDecode(batchesJson) as List;
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final batchKey = (m['batch_key'] ?? '') as String;
        if (batchKey.isNotEmpty) {
          completedItems[batchKey] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
          changed = true;
          final name = (m['name'] ?? '') as String;
          final itemType = (m['item_type'] ?? '') as String;
          final itemId = (m['item_id'] ?? '') as String;
          final source = (m['source'] ?? '') as String;
          if (name.isNotEmpty) {
            _batchMeta[batchKey] = _BatchMeta(name, itemType, itemId, source);
          }
          // Build reverse map: trackId → batchKey for cover backfill
          final trackIdsRaw = (m['track_ids'] ?? '') as String;
          if (trackIdsRaw.isNotEmpty) {
            try {
              final parsedIds = jsonDecode(trackIdsRaw) as List;
              for (final tid in parsedIds) {
                final ntid = normalizeTrackId(tid.toString());
                batchTrackMap[ntid] = batchKey;
              }
            } catch (_) {}
          }
        }
      }
    }
    _lastBatchesTimestamp = DateTime.now().toUtc().toIso8601String();

    // ── 3. Backfill: for tracks with null covers, try album/playlist cover ──
    if (batchTrackMap.isNotEmpty) {
      final likeCubit = sl<LikeCubit>();
      for (final entry in _trackMeta.entries) {
        final meta = entry.value;
        if (meta.coverUrl != null && meta.coverUrl!.isNotEmpty) continue;
        if (meta.coverPath != null && meta.coverPath!.isNotEmpty) continue;
        final batchKey = batchTrackMap[meta.trackId];
        if (batchKey == null) continue;
        final bm = _batchMeta[batchKey];
        if (bm == null) continue;
        final likedAlbum = likeCubit.state.allLiked.values
            .where((i) => i.type == bm.itemType && normalizeTrackId(i.id) == normalizeTrackId(bm.itemId))
            .firstOrNull;
        final albumCover = likedAlbum?.localCoverPath?.isNotEmpty == true
            ? likedAlbum!.localCoverPath
            : likedAlbum?.coverUrl;
        if (albumCover != null && albumCover.isNotEmpty) {
          _trackMeta[entry.key] = _TrackInfo(
            meta.trackId, meta.name, meta.artist, albumCover, meta.source, meta.coverPath,
          );
          changed = true;
        }
      }
    }

    if (changed) {
      // Mergear los items completados en el estado ACTUAL para no perder
      // items in-progress agregados concurrentemente por _pollProgress().
      // Don't overwrite in-progress items — they reflect an active download.
      final dl = Map<String, DownloadStateData>.from(state.downloads);
      for (final entry in completedItems.entries) {
        final existing = dl[entry.key];
        if (existing?.state == DownloadState.inProgress) continue;
        if (existing?.state != DownloadState.completed) {
          dl[entry.key] = entry.value;
        }
      }
      emit(state.copyWith(downloads: dl, downloadedFingerprints: fps));
    }
  }

  /// Decrypts an encrypted/DRM downloaded file (e.g. amazon FLAC with a
  /// mov_key) via ffmpeg-kit when the Go backend had no CLI ffmpeg to do it
  /// (Android). Writes the playable file next to the encrypted one, deletes
  /// the encrypted original on success and returns the decrypted path (or
  /// null on failure). Mirrors the streaming path in [PlayerCubit].
  Future<String?> _decryptDownloadedFile(String srcPath, String key, String ext) async {
    final srcFile = File(srcPath);
    if (!await srcFile.exists()) return null;
    var outExt = ext.trim();
    if (outExt.isEmpty) outExt = '.flac';
    if (!outExt.startsWith('.')) outExt = '.$outExt';
    final dir = srcFile.parent.path;
    final base = srcFile.uri.pathSegments.last;
    final baseName = base.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final outPath = '$dir${Platform.pathSeparator}$baseName.dec$outExt';
    final args = '-decryption_key $key -y -i ${_q(srcPath)} -c copy ${_q(outPath)}';
    try {
      final session = await FFmpegKit.execute(args);
      if (ReturnCode.isSuccess(await session.getReturnCode()) && await File(outPath).exists()) {
        try {
          await srcFile.delete();
        } catch (_) {}
        return outPath;
      }
      // ignore: avoid_print
      _log.e('[DownloadCubit] ffmpeg-kit decrypt failed: ${await session.getAllLogsAsString()}');
    } catch (e) {
      // ignore: avoid_print
      _log.e('[DownloadCubit] ffmpeg-kit decrypt error: $e');
    }
    try {
      if (await File(outPath).exists()) await File(outPath).delete();
    } catch (_) {}
    return null;
  }

  /// Quotes a path for the ffmpeg-kit command line.
  String _q(String p) => "'${p.replaceAll("'", "\\'")}'";

  /// One-time startup scan that detects downloaded files that are NOT playable
  /// audio (e.g. the encrypted amazon streams that were saved before downloads
  /// were decrypted via ffmpeg-kit). Such files are deleted, their DB rows
  /// removed, and the tracks are re-downloaded automatically so they play.
  Future<void> _repairBrokenDownloads() async {
    if (_repairAttempted) return;
    _repairAttempted = true;
    try {
      final historyJson = await _downloadCache.getDownloadHistory();
      if (historyJson.isEmpty || historyJson == '[]') return;
      final list = jsonDecode(historyJson) as List;
      final broken = <Map<String, dynamic>>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final fp = (m['file_path'] ?? '').toString();
        if (fp.isEmpty) continue;
        final file = File(fp);
        if (!await file.exists()) continue;
        if (!await _isDecodableAudioFile(file)) {
          broken.add(m);
          _log.w('[DownloadCubit] Descarga corrupta detectada: $fp');
        }
      }
      if (broken.isEmpty) return;
      _log.w('[DownloadCubit] Reparando ${broken.length} descarga(s) corrupta(s)...');

      // Remove broken DB rows and delete the unusable files.
      final brokenIds = broken
          .map((m) => (m['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
      if (brokenIds.isNotEmpty) {
        await _downloadCache.deleteDownloadedTracks(brokenIds);
      }
      for (final m in broken) {
        try {
          final file = File((m['file_path'] ?? '').toString());
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      sl<LibraryCache>().invalidateAll();

      // Re-download each repaired track (uses the new decrypt-on-download path).
      for (final m in broken) {
        await _redownloadBrokenTrack(m);
      }
    } catch (e) {
      _log.e('[DownloadCubit] repair error: $e');
    }
  }

  /// Re-downloads a single broken track discovered by [_repairBrokenDownloads],
  /// reconstructing the dispatch strategy from its DB history row.
  Future<void> _redownloadBrokenTrack(Map<String, dynamic> m) async {
    try {
      final trackId = ((m['providerTrackId'] ?? m['id']) ?? '').toString();
      if (trackId.isEmpty) return;
      final src = ((m['providerSource'] ?? m['service']) ?? '').toString();
      if (src.isEmpty) return; // cannot re-download without a known source

      final baseId = 'track_${normalizeTrackId(trackId)}_$src';
      if (state.downloads[baseId]?.state == DownloadState.inProgress) return;

      final commonMeta = <String, dynamic>{
        'track_id': trackId,
        'item_id': (m['id'] ?? trackId).toString(),
        'track_title': (m['track_name'] ?? '').toString(),
        'artist_name': (m['artist_name'] ?? '').toString(),
        'album_name': (m['album_name'] ?? '').toString(),
        'source': src,
        'isrc': (m['isrc'] ?? '').toString(),
        'duration_ms': (m['duration'] ?? 0),
        if ((m['cover_url'] ?? '').toString().isNotEmpty)
          'cover_url': (m['cover_url'] ?? '').toString(),
      };
      dispatchSingleTrack(
        commonMeta: commonMeta,
        settings: const DownloadSettings(),
        baseId: baseId,
      );
    } catch (e) {
      _log.e('[DownloadCubit] redownload error: $e');
    }
  }

  /// Quick magic-byte check for whether a downloaded file is playable audio.
  /// The known broken files are encrypted amazon DRM streams saved with a
  /// `.flac` extension (they are actually MP4/fMP4 containers, not FLAC). A
  /// real FLAC file always starts with the `fLaC` marker.
  Future<bool> _isDecodableAudioFile(File file) async {
    try {
      final name = file.path.split(RegExp(r'[/\\]')).last.toLowerCase();
      final dot = name.lastIndexOf('.');
      final ext = dot >= 0 ? name.substring(dot + 1) : '';
      final raf = await file.open(mode: FileMode.read);
      final magic = await raf.read(8);
      await raf.close();
      if (magic.length < 4) return false;
      switch (ext) {
        case 'flac':
          return magic[0] == 0x66 && magic[1] == 0x4C &&
              magic[2] == 0x61 && magic[3] == 0x43; // "fLaC"
        case 'mp3':
          if (magic[0] == 0x49 && magic[1] == 0x44 && magic[2] == 0x33) return true; // ID3
          if (magic[0] == 0xFF && (magic[1] & 0xE0) == 0xE0) return true; // MPEG frame
          return false;
        case 'wav':
          return magic[0] == 0x52 && magic[1] == 0x49 &&
              magic[2] == 0x46 && magic[3] == 0x46; // "RIFF"
        case 'ogg':
        case 'opus':
          return magic[0] == 0x4F && magic[1] == 0x67 &&
              magic[2] == 0x67 && magic[3] == 0x53; // "OggS"
        default:
          // mp4/m4a/aac and unknown extensions are structurally valid MP4
          // containers even when encrypted, so they can't be sniffed cheaply.
          return true;
      }
    } catch (_) {
      return false;
    }
  }

  void _ensurePolling() {
    if (_progressTimer == null || !_progressTimer!.isActive) {
      _startPolling();
    }
  }

  void _startPolling() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final hasActive = state.downloads.values
          .any((d) => d.state == DownloadState.inProgress);
      if (hasActive || _emptyProgressStreak > 0) {
        _pollProgress();
      } else {
        // No active downloads and no cleanup streak needed — stop polling
        _progressTimer?.cancel();
        _progressTimer = null;
      }
    });
  }

  void _startHistoryRefresh() {
    _historyTimer?.cancel();
    _historyTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadHistory().catchError((_) {});
    });
  }

  /// Normalizes a Go progress entry's status field into a string. The Go
  /// tracker used to marshal Status as an integer (0=queued … 5=cancelled),
  /// so accept BOTH the numeric and the string form. A hard cast here would
  /// throw on the first item of every poll, get swallowed by the outer catch
  /// and leave every download stuck orange (inProgress) forever — the file
  /// existed on disk but the dot never turned green.
  String _statusOf(Map<String, dynamic> p) {
    final raw = p['status'];
    if (raw is String) return raw;
    if (raw is num) {
      switch (raw.toInt()) {
        case 0:
          return 'queued';
        case 1:
          return 'downloading';
        case 2:
          return 'processing';
        case 3:
          return 'completed';
        case 4:
          return 'failed';
        case 5:
          return 'cancelled';
      }
    }
    return '';
  }

  Future<void> _pollProgress() async {
    if (_verificationInProgress || _pollingInProgress) return;
    _pollingInProgress = true;

    try {
      // ── 1. Check real-time progress from backend ──────────
      final json = await _backend.getAllDownloadProgress();
      final data = json.isNotEmpty ? jsonDecode(json) : null;
      final rawItems = (data is Map) ? data['items'] : null;
      final items = (rawItems is Map<String, dynamic>) ? rawItems : <String, dynamic>{};

      // ── 0. Check if any item needs verification ──────────
      if (items.isNotEmpty) {
        for (final entry in items.entries) {
          if (entry.value is! Map) continue;
          final p = entry.value as Map<String, dynamic>;
          final status = _statusOf(p);
          if (status == 'verification_required') {
            _log.i('[_pollProgress] Detected verification_required for ${entry.key}');

            // Mark all in-progress downloads as interrupted so retryAllInterrupted
            // picks them up after verification completes
            final dl = Map<String, DownloadStateData>.from(state.downloads);
            bool changed = false;
            for (final k in dl.keys) {
              if (dl[k]!.state == DownloadState.inProgress) {
                dl[k] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
                changed = true;
              }
            }
            if (changed) {
              emit(state.copyWith(downloads: dl));
            }

            _progressTimer?.cancel();
            _verificationInProgress = true;
            _handleVerificationRequired().then((_) {
              _verificationInProgress = false;
              _startPolling();
            });
            return;
          }
        }
      }

      bool hasLiveItems = false;

      final dl = Map<String, DownloadStateData>.from(state.downloads);
      final fps = Set<String>.from(state.downloadedFingerprints);
      bool changed = false;

      if (items.isNotEmpty) {
        hasLiveItems = true;
        _emptyProgressStreak = 0;

        for (final entry in items.entries) {
          final rawId = entry.key.toString();
          // Translate Go backend item_id to our state key
          final stateKey = _itemIdToStateKey[rawId] ?? rawId;
          if (entry.value is! Map) continue;
          final p = entry.value as Map<String, dynamic>;
          final status = _statusOf(p);
          final progress = (p['progress'] ?? 0.0) as num;
          final trackName = (p['track_name'] ?? '') as String;
          final artistName = (p['artist_name'] ?? '') as String;

          final outputPath = (p['outputPath'] ?? p['file_path'] ?? '') as String;
          final encrypted = (p['encrypted'] ?? false) == true;
          final clientDecrypt = (p['clientDecrypt'] ?? false) == true;
          final decKey = (p['decryptionKey'] ?? '').toString();
          final outExt = (p['outputExtension'] ?? '').toString();
          if (status == 'completed' || status == 'finalizing') {
            // Only persist to DB and save cover for the BASE (audio) completion.
            // Lyrics/video subtasks have their own completion events but their
            // stateKey is a subtask key (e.g. track_123_deezer_lyrics) where
            // _trackMeta has no entry — would produce a wrong trackId.
            final isSubTask = stateKey.endsWith('_lyrics') || stateKey.endsWith('_video');

            // Encrypted/DRM download with a decryption key and no CLI ffmpeg
            // in the backend (Android): decrypt here via ffmpeg-kit — the
            // same step the streaming path performs — before persisting a
            // playable file. Otherwise the stored file is an unplayable
            // encrypted stream ("Error decoding audio" on every tap).
            var playablePath = outputPath;
            if (!isSubTask && playablePath.isNotEmpty && encrypted && clientDecrypt && decKey.isNotEmpty) {
              if (_clientDecryptDone.contains(rawId)) {
                // Already decrypted & persisted on an earlier poll — never
                // re-save the (now deleted) encrypted path.
                continue;
              }
              final decrypted = await _decryptDownloadedFile(playablePath, decKey, outExt);
              if (decrypted == null || decrypted.isEmpty) {
                // Decryption failed — don't persist a broken file. Flag the
                // item as interrupted so the user can retry the download.
                dl[stateKey] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
                _startedAt.remove(stateKey);
                _pendingDecryptError = 'decrypt';
                changed = true;
                continue;
              }
              _clientDecryptDone.add(rawId);
              playablePath = decrypted;
            }

            dl[stateKey] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
            // Also update sibling subtask keys (audio/lyrics/video) if they exist
            final audioKey = '${stateKey}_audio';
            if (dl.containsKey(audioKey)) {
              dl[audioKey] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
            }
            final lyricsKey = '${stateKey}_lyrics';
            if (dl.containsKey(lyricsKey)) {
              dl[lyricsKey] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
            }
            final videoKey = '${stateKey}_video';
            if (dl.containsKey(videoKey)) {
              dl[videoKey] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
            }

            if (!isSubTask) {
              final meta = _trackMeta[stateKey];
              final trackId = meta?.trackId ?? (stateKey.startsWith('track_') && stateKey.length > 6
                  ? stateKey.substring(6, stateKey.lastIndexOf('_'))
                  : rawId);
              final src = meta?.source ?? (stateKey.contains('_') ? stateKey.split('_').last : '');

              // Save cover locally for offline persistence (like liked tracks).
              // saveCover returns the absolute path so covers also render on
              // platforms without the desktop HTTP server (Android).
              final trackCoverUrl = meta?.coverUrl;
              String? coverPath;
              if (trackCoverUrl != null && trackCoverUrl.isNotEmpty) {
                try {
                  final coverPathResult = await _backend.saveCover(trackCoverUrl);
                  if (coverPathResult != null && coverPathResult.isNotEmpty) {
                    coverPath = coverPathResult;
                  }
                } catch (_) {
                  coverPath = null;
                }
                if (coverPath != null && coverPath.isNotEmpty && meta != null) {
                  _trackMeta[stateKey] = _TrackInfo(
                    meta.trackId, meta.name, meta.artist, meta.coverUrl, meta.source, coverPath,
                  );
                }
              }

              unawaited(_downloadCache.saveDownloadedTrack(
                id: trackId,
                trackName: trackName.isNotEmpty ? trackName : rawId,
                artistName: artistName.isNotEmpty ? artistName : '',
                service: src,
                filePath: playablePath.isNotEmpty ? playablePath : null,
                providerTrackId: rawId.endsWith('_audio')
                    ? rawId.substring(0, rawId.length - 6)
                    : rawId.endsWith('_lyrics')
                        ? rawId.substring(0, rawId.length - 7)
                        : rawId.endsWith('_video')
                            ? rawId.substring(0, rawId.length - 6)
                            : rawId,
                providerSource: src,
                coverUrl: trackCoverUrl,
                coverPath: coverPath,
              ));

              final fpName = trackName.isNotEmpty ? trackName : rawId;
              final fpArtist = trackName.isNotEmpty ? artistName : '';
              fps.add(fingerprintFromName(fpName, fpArtist));
            }
            _startedAt.remove(stateKey);
            changed = true;
          } else if (status == 'downloading' || status == 'preparing') {
            dl[stateKey] = DownloadStateData(state: DownloadState.inProgress, progress: progress.toDouble());
            changed = true;
          } else if (status == 'failed' || status == 'cancelled') {
            // Backend exhausted all providers without producing a file. Surface
            // a terminal state (interrupted → red/retry) instead of leaving the
            // card stuck orange (inProgress) forever.
            dl[stateKey] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
            _startedAt.remove(stateKey);
            changed = true;
          }
        }
      }

      // ── 2. Recompute batch (album/playlist) aggregate progress ──
      for (final batchKey in _batchTrackIds.keys.toList()) {
        final trackIds = _batchTrackIds[batchKey]!;
        if (trackIds.isEmpty) { _batchTrackIds.remove(batchKey); continue; }

        int completed = 0;
        int stopped = 0;
        for (final id in trackIds) {
          final st = dl[id]?.state;
          if (st == DownloadState.completed) {
            completed++;
          } else if (st == DownloadState.none || st == DownloadState.interrupted) {
            stopped++;
          }
        }
        final total = trackIds.length;
        final progress = total > 0 ? completed / total : 0.0;

        final allDone = (completed + stopped) >= total;

        if (allDone) {
          final completedState = completed == total ? DownloadState.completed : DownloadState.none;
          dl[batchKey] = DownloadStateData(state: completedState, progress: progress);
          _batchTrackIds.remove(batchKey);
          if (completedState == DownloadState.completed) {
            final parts = batchKey.split('_');
            if (parts.length >= 2) {
              final itemType = parts[0];
              final src = parts.last;
              final itemId = parts.sublist(1, parts.length - 1).join('_');
              final batchData = _batchData[batchKey];
              final batchName = (batchData?.tracks.isNotEmpty == true)
                  ? (batchData!.tracks.first['album_name'] as String? ?? '')
                  : '';
              _batchMeta[batchKey] = _BatchMeta(batchName, itemType, itemId, src);
              _downloadCache.saveDownloadedBatch(batchKey, itemType, itemId, src, batchName,
                trackIds: trackIds,
              );
              sl<LibraryCache>().invalidateAll();
            }
          }
          changed = true;
        } else if (completed > 0) {
          dl[batchKey] = DownloadStateData(state: DownloadState.inProgress, progress: progress);
          changed = true;
        }
      }

      if (changed) {
        emit(state.copyWith(
          downloads: dl,
          downloadedFingerprints: fps,
          decryptError: _pendingDecryptError,
        ));
      }

      // ── 3. Timeout detection ──────────────────────────────
      // If we have in-progress items but no live progress from backend
      // for ~12s (4 polls), mark them as interrupted.
      final hasInProgress = state.downloads.values
          .any((d) => d.state == DownloadState.inProgress);
      if (hasInProgress && !hasLiveItems) {
        _emptyProgressStreak++;
        if (_emptyProgressStreak >= 6) {
          final dl = Map<String, DownloadStateData>.from(state.downloads);
          bool changed = false;
          for (final key in dl.keys) {
            if (dl[key]!.state == DownloadState.inProgress) {
              dl[key] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
              changed = true;
            }
          }
          if (changed) emit(state.copyWith(downloads: dl));
          _emptyProgressStreak = 0;
        }
      } else if (!hasInProgress) {
        _emptyProgressStreak = 0;
      }

      // ── 4. Hard timeout: mark items stuck over 120s as none ──
      final now = DateTime.now();
      final hardDl = Map<String, DownloadStateData>.from(state.downloads);
      bool hardTimedOut = false;
      for (final id in _startedAt.keys.toList()) {
        if (hardDl[id]?.state != DownloadState.inProgress) {
          _startedAt.remove(id);
          continue;
        }
        if (now.difference(_startedAt[id]!) > const Duration(seconds: 120)) {
          hardDl[id] = const DownloadStateData(state: DownloadState.none, progress: 0.0);
          _startedAt.remove(id);
          hardTimedOut = true;
        }
      }
      if (hardTimedOut) emit(state.copyWith(downloads: hardDl));
    } catch (_) {
    } finally {
      _pollingInProgress = false;
    }
  }

  /// Clears the backendRestarted flag after the user has seen the notification.
  void acknowledgeRestart() {
    if (state.backendRestarted) {
      emit(state.copyWith(backendRestarted: false));
    }
  }

  /// Clears a pending decrypt-error snackbar for the current session.
  void acknowledgeDecryptError() {
    if (_pendingDecryptError != null) {
      _pendingDecryptError = null;
      emit(state.copyWith(decryptError: null, clearDecryptError: true));
    }
  }

  /// Called when _pollProgress detects a "verification_required" status on one
  /// or more download items. Iterates through all known providers, checks for
  /// pending auth URLs, shows the verification WebView for each, and retries
  /// interrupted batches once verification completes.
  Future<void> _handleVerificationRequired() async {
    _log.i('[_handleVerificationRequired] Starting...');
    final service = VerificationService();
    if (!service.isReady) {
      _log.w('[_handleVerificationRequired] VerificationService not initialized');
      return;
    }

    try {
      for (final extId in _providerDisplayNames.keys) {
        // Only process providers that have a pending verification URL.
        // Skip proactively triggering — avoids corrupting public API
        // extensions (e.g. Deezer) that don't need auth.
        var url = await _backend.getPendingVerificationUrl(extId);
        _log.i('[$extId] getPendingVerificationUrl -> "$url"');
        if (url.isEmpty) {
          _log.i('[$extId] no pending auth URL, skipping');
          continue;
        }

        final displayName = _providerDisplayNames[extId] ?? extId;
        _log.i('[$extId] showing WebView for $displayName');

        final grant = await service.showVerification(
          extId: extId,
          displayName: displayName,
          authUrl: url,
        );

        if (grant == null || grant.isEmpty) {
          _log.w('[$extId] no grant obtained');
          continue;
        }

        _log.i('[$extId] completing grant (len=${grant.length})');
        final ok = await _backend.completeSignedSessionGrant(extId, grant);
        _log.i('[$extId] grant result: $ok');
      }

      // After all verifications, retry interrupted batch tracks
      _log.i('[_handleVerificationRequired] Verification done, retrying interrupted batches');
      retryAllInterrupted();
    } catch (e) {
      _log.e('[_handleVerificationRequired] Error: $e');
    }
  }

  /// Retries ALL interrupted / failed batch downloads.
  /// Iterates over current state and calls [retryFailedBatchTracks] for each
  /// interrupted or failed (none) album/playlist batch that still has stored
  /// batch data. Hard timeouts set the batch to [DownloadState.none] directly,
  /// so we must check for both.
  void retryAllInterrupted() {
    final retryBatchKeys = state.downloads.entries
        .where((e) =>
            (e.value.state == DownloadState.interrupted || e.value.state == DownloadState.none) &&
            (e.key.startsWith('album_') || e.key.startsWith('playlist_')) &&
            _batchData.containsKey(e.key))
        .map((e) => e.key)
        .toList();

    if (retryBatchKeys.isEmpty) return;

    for (final batchKey in retryBatchKeys) {
      retryFailedBatchTracks(batchKey);
    }
  }

  DownloadStateData downloadStateFor(String id) =>
      state.downloads[id] ?? const DownloadStateData();

  /// SHA-1 hex digest, matches Go's [utils.HashString].
  String _sha1Hex(String input) => sha1.convert(utf8.encode(input)).toString();

  /// Sanitize filename to match Go's [utils.SanitizeFilename].
  String _sanitizeFilename(String name) {
    const invalid = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    var result = name;
    for (final ch in invalid) {
      result = result.replaceAll(ch, '_');
    }
    result = result.replaceAll(RegExp(r'^[. ]+'), '').replaceAll(RegExp(r'[. ]+$'), '');
    return result.isEmpty ? 'unknown' : result;
  }

  /// Returns the best available cover for a downloaded track:
  /// local cover path (if saved) → remote cover URL → null.
  String? localTrackCover(String trackId, String source) {
    final key = 'track_${normalizeTrackId(trackId)}_$source';
    final meta = _trackMeta[key];
    return meta?.coverPath ?? meta?.coverUrl;
  }

  /// Returns the stored name for a batch key (album/playlist name),
  /// or empty string if not available.
  String batchNameFor(String batchKey) => _batchMeta[batchKey]?.name ?? '';

  /// Retry only the failed (non-completed) tracks from a previous batch.
  /// [batchKey] should match the key used in [startAlbumDownload] or [startPlaylistDownload]
  /// (e.g. "album_123_spotify"). Stored original track data is reused.
  void retryFailedBatchTracks(String batchKey) {
    final data = _batchData[batchKey];
    if (data == null) return;
    if (state.downloads[batchKey]?.state == DownloadState.inProgress) return;

    // Find which tracks are NOT completed
    final failed = <Map<String, dynamic>>[];
    for (final t in data.tracks) {
      final tid = (t['track_id'] as String?) ?? '';
      if (tid.isEmpty) continue;
      // Normalizar para que el lookup coincida con las keys de batch
      final audioId = 'track_${normalizeTrackId(tid)}_${data.source}';
      if (state.downloads[audioId]?.state != DownloadState.completed) {
        failed.add(t);
      }
    }
    if (failed.isEmpty) return;

    final dl = Map<String, DownloadStateData>.from(state.downloads);
    final audioIds = <String>[];
    for (final t in failed) {
      final tid = (t['track_id'] as String?) ?? '';
      if (tid.isEmpty) continue;
      final normalizedTid = normalizeTrackId(tid);
      final audioId = 'track_${normalizedTid}_${data.source}';
      audioIds.add(audioId);
      // Pre-seed so retryFailedBatchTracks' final emit doesn't overwrite
      // dispatchSingleTrack's entries (same race as Bug 4 in startPlaylistDownload).
      dl[audioId] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
      _dispatchBatchTrack(t, tid, data.source, data.settings, qualityOverride: data.qualityOverride);
    }

    _batchTrackIds[batchKey] = audioIds;

    // Reset batch state to inProgress (dl already has the pre-seeded tracks)
    dl[batchKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
    emit(state.copyWith(downloads: dl));
  }

  Future<bool> _checkAllSessionsBeforeDownload() async {
    return true;
  }

  void startDownload(String id, {Map<String, dynamic>? strategy}) async {
    if (state.downloads[id]?.state == DownloadState.inProgress) return;
    if (!await _checkAllSessionsBeforeDownload()) return;
    final dl = Map<String, DownloadStateData>.from(state.downloads);
    dl[id] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
    emit(state.copyWith(downloads: dl));
    _startedAt[id] = DateTime.now();

    final s = strategy ?? {'type': 'audio'};
    // Include user_id for free/premium quota enforcement
    s['user_id'] = _userId;
    _backend.downloadByStrategy(jsonEncode(s));
    // (progress tracking is handled by the Go backend via item_id in the strategy map)
    _ensurePolling();
  }

  /// Start downloading an album — each track one by one with user settings.
  ///
  /// [tracks] should be a list of maps with keys:
  /// `track_id`, `track_title`, `artist_name`, `album_name`, `source`, `isrc`, `duration_ms`.
  /// [settings] provides the user's download preferences (quality, video, lyrics).
  /// [source] is the provider source (e.g. "spotify", "deezer") used to construct
  /// the batch key that the grid looks up for aggregate progress display.
  /// [qualityOverride] overrides the audio quality for all tracks in this batch.
  void startAlbumDownload(
    String albumId,
    List<Map<String, dynamic>> tracks, {
    DownloadSettings? settings,
    String source = '',
    String? qualityOverride,
  }) async {
    final batchKey = 'album_${normalizeTrackId(albumId)}_$source';
    if (state.downloads[batchKey]?.state == DownloadState.inProgress) return;
    if (tracks.isEmpty) return;
    if (!await _checkAllSessionsBeforeDownload()) return;

    final s = settings ?? const DownloadSettings();
    final audioIds = <String>[];
    final dl = Map<String, DownloadStateData>.from(state.downloads);

    for (final t in tracks) {
      final tid = (t['track_id'] as String?) ?? '';
      if (tid.isEmpty) continue;
      final normalizedTid = normalizeTrackId(tid);
      final baseId = 'track_${normalizedTid}_$source';
      audioIds.add(baseId);

      final alreadyDone = _downloadedTrackIds.contains(normalizedTid)
          || state.downloads[baseId]?.state == DownloadState.completed;
      if (alreadyDone) {
        _ensureTrackMeta(baseId, normalizedTid, t, source);
        dl[baseId] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
        continue;
      }

      dl[baseId] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
      _dispatchBatchTrack(t, tid, source, s, qualityOverride: qualityOverride);
    }

    if (audioIds.isEmpty) return;
    _batchTrackIds[batchKey] = audioIds;
    _batchData[batchKey] = _BatchData(tracks, s, source, qualityOverride);
    _ensurePolling();

    // Create batch-level entry so the grid shows an orange ring
    dl[batchKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
    emit(state.copyWith(downloads: dl));
  }

  void startPlaylistDownload(
    String playlistId,
    List<Map<String, dynamic>> tracks, {
    DownloadSettings? settings,
    String source = '',
    String? qualityOverride,
  }) async {
    final batchKey = 'playlist_${normalizeTrackId(playlistId)}_$source';
    if (state.downloads[batchKey]?.state == DownloadState.inProgress) return;
    if (tracks.isEmpty) return;
    if (!await _checkAllSessionsBeforeDownload()) return;

    final s = settings ?? const DownloadSettings();
    final audioIds = <String>[];
    final dl = Map<String, DownloadStateData>.from(state.downloads);

    _log.i('[startPlaylistDownload] batchKey=$batchKey tracks=${tracks.length} source=$source');

    for (final t in tracks) {
      final tid = (t['track_id'] as String?) ?? '';
      if (tid.isEmpty) { _log.w('[startPlaylistDownload] SKIP empty tid'); continue; }
      final normalizedTid = normalizeTrackId(tid);
      final baseId = 'track_${normalizedTid}_$source';
      audioIds.add(baseId);

      final alreadyDone = _downloadedTrackIds.contains(normalizedTid)
          || state.downloads[baseId]?.state == DownloadState.completed;
      if (alreadyDone) {
        _log.i('[startPlaylistDownload] ALREADY_DONE tid=$tid baseId=$baseId');
        _ensureTrackMeta(baseId, normalizedTid, t, source);
        dl[baseId] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
        continue;
      }

      _log.i('[startPlaylistDownload] DISPATCH tid=$tid baseId=$baseId');
      // Pre-seed state so startPlaylistDownload's final emit includes
      // this track.  Without this, dispatchSingleTrack's own emit is
      // overwritten by startPlaylistDownload's final emit because the
      // dl snapshot was taken before the dispatch.
      dl[baseId] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
      _dispatchBatchTrack(t, tid, source, s, qualityOverride: qualityOverride);
    }

    _log.i('[startPlaylistDownload] loop done: audioIds=${audioIds.length}');
    if (audioIds.isEmpty) { _log.w('[startPlaylistDownload] audioIds EMPTY'); return; }
    _batchTrackIds[batchKey] = audioIds;
    _batchData[batchKey] = _BatchData(tracks, s, source, qualityOverride);
    _log.i('[startPlaylistDownload] batch registered, _batchTrackIds.size=${_batchTrackIds.length}');
    _ensurePolling();

    // Create batch-level entry so the grid shows an orange ring
    dl[batchKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
    emit(state.copyWith(downloads: dl));
  }

  /// Deletes all downloaded tracks for an album batch.
  /// Removes files from disk, DB entries, and local state.
  Future<void> deleteAlbumDownload(String albumId, String source) async {
    final batchKey = 'album_${normalizeTrackId(albumId)}_$source';
    final data = _batchData[batchKey];
    if (data != null) {
      await _deleteBatch(batchKey);
      return;
    }
    // After restart: try to get track IDs from batch entry
    var batch = await _downloadCache.getBatchByItem('album', albumId, source);
    var effectiveSource = source;
    if (batch == null && source.isNotEmpty) {
      batch = await _downloadCache.getBatchByItem('album', albumId, '');
      if (batch != null) effectiveSource = '';
    }
    final stateKeys = batch?.trackIds != null && batch!.trackIds!.isNotEmpty
        ? (jsonDecode(batch.trackIds!) as List<dynamic>).cast<String>()
        : <String>[];
    if (stateKeys.isNotEmpty) {
      // stateKeys are like "track_normalizedId_source"; extract normalized IDs
      // and also try original formats for robust DB deletion
      final allIds = <String>{};
      final fileStems = <String>{};
      for (final stateKey in stateKeys) {
        allIds.add(stateKey);
        final parts = stateKey.split('_');
        if (parts.length >= 3) {
          final extractedId = parts.sublist(1, parts.length - 1).join('_');
          allIds.add(extractedId);
          fileStems.add(extractedId);
          // lyrics_{sha1} – try normalized and also look up original in _trackMeta
          fileStems.add('lyrics_${_sha1Hex(extractedId)}');
          final meta = _trackMeta[stateKey];
          if (meta != null) {
            fileStems.add('lyrics_${_sha1Hex(meta.trackId)}');
            if (meta.name.isNotEmpty && meta.artist != null && meta.artist!.isNotEmpty) {
              fileStems.add('${_sanitizeFilename(meta.artist!)} - ${_sanitizeFilename(meta.name)}');
            }
            if (meta.coverUrl != null && meta.coverUrl!.isNotEmpty) {
              try { await _backend.deleteCover(meta.coverUrl!); } catch (_) {}
            }
          }
        }
      }
      await _downloadCache.deleteDownloadedTracks(allIds.toList());
      sl<PlayerCubit>().removeLocalFilesProviderIds(fileStems.toList(), deleteFiles: true);
    }
    await _downloadCache.removeDownloadedBatchByItem('album', albumId, effectiveSource);
    sl<LibraryCache>().invalidateAll();
    final dl = Map<String, DownloadStateData>.from(state.downloads);
    dl.remove(batchKey);
    emit(state.copyWith(downloads: dl));
  }

  /// Deletes all downloaded tracks for a playlist batch.
  Future<void> deletePlaylistDownload(String playlistId, String source) async {
    final batchKey = 'playlist_${normalizeTrackId(playlistId)}_$source';
    final data = _batchData[batchKey];
    if (data != null) {
      await _deleteBatch(batchKey);
      return;
    }
    // After restart: try to get track IDs from batch entry
    var batch = await _downloadCache.getBatchByItem('playlist', playlistId, source);
    var effectiveSource = source;
    if (batch == null && source.isNotEmpty) {
      batch = await _downloadCache.getBatchByItem('playlist', playlistId, '');
      if (batch != null) effectiveSource = '';
    }
    final stateKeys = batch?.trackIds != null && batch!.trackIds!.isNotEmpty
        ? (jsonDecode(batch.trackIds!) as List<dynamic>).cast<String>()
        : <String>[];
    if (stateKeys.isNotEmpty) {
      final allIds = <String>{};
      final fileStems = <String>{};
      for (final stateKey in stateKeys) {
        allIds.add(stateKey);
        final parts = stateKey.split('_');
        if (parts.length >= 3) {
          final extractedId = parts.sublist(1, parts.length - 1).join('_');
          allIds.add(extractedId);
          fileStems.add(extractedId);
          fileStems.add('lyrics_${_sha1Hex(extractedId)}');
          final meta = _trackMeta[stateKey];
          if (meta != null) {
            fileStems.add('lyrics_${_sha1Hex(meta.trackId)}');
            if (meta.name.isNotEmpty && meta.artist != null && meta.artist!.isNotEmpty) {
              fileStems.add('${_sanitizeFilename(meta.artist!)} - ${_sanitizeFilename(meta.name)}');
            }
            if (meta.coverUrl != null && meta.coverUrl!.isNotEmpty) {
              try { await _backend.deleteCover(meta.coverUrl!); } catch (_) {}
            }
          }
        }
      }
      await _downloadCache.deleteDownloadedTracks(allIds.toList());
      sl<PlayerCubit>().removeLocalFilesProviderIds(fileStems.toList(), deleteFiles: true);
    }
    await _downloadCache.removeDownloadedBatchByItem('playlist', playlistId, effectiveSource);
    sl<LibraryCache>().invalidateAll();
    final dl = Map<String, DownloadStateData>.from(state.downloads);
    dl.remove(batchKey);
    emit(state.copyWith(downloads: dl));
  }

  Future<void> _deleteBatch(String batchKey) async {
    final data = _batchData[batchKey];
    if (data == null) return;

    final allIdsToDelete = <String>{};
    final audioIdsInBatch = <String>[];
    final fileStems = <String>{};
    for (final t in data.tracks) {
      final originalId = (t['track_id'] as String?) ?? '';
      if (originalId.isEmpty) continue;
      final normalizedId = normalizeTrackId(originalId);
      allIdsToDelete.add(originalId);
      allIdsToDelete.add(normalizedId);
      audioIdsInBatch.add('track_${normalizedId}_${data.source}');
      fileStems.addAll({originalId, normalizedId});
      // lyrics_{sha1(TrackID)} – try both original and normalized
      for (final id in {originalId, normalizedId}) {
        if (id.isNotEmpty) fileStems.add('lyrics_${_sha1Hex(id)}');
      }
      // video: {sanitizedArtist} - {sanitizedTitle}.mp4
      final title = (t['track_title'] as String?) ?? '';
      final artist = (t['artist_name'] as String?) ?? '';
      if (title.isNotEmpty && artist.isNotEmpty) {
        fileStems.add('${_sanitizeFilename(artist)} - ${_sanitizeFilename(title)}');
      }
      // cover in coversDir – only delete if track is NOT also liked
      final coverUrl = (t['cover_url'] as String?) ?? '';
      if (coverUrl.isNotEmpty) {
        final likeCubit = sl<LikeCubit>();
        final isLiked = [originalId, normalizedId]
            .any((id) => id.isNotEmpty && likeCubit.isItemIdLiked(id));
        if (!isLiked) {
          try { await _backend.deleteCover(coverUrl); } catch (_) {}
        }
      }
    }
    if (allIdsToDelete.isEmpty) return;

    await _downloadCache.deleteDownloadedTracks(allIdsToDelete.toList());
    await _downloadCache.removeDownloadedBatches([batchKey]);

    sl<PlayerCubit>().removeLocalFilesProviderIds(fileStems.toList(), deleteFiles: true);
    sl<LibraryCache>().invalidateAll();

    final dl = Map<String, DownloadStateData>.from(state.downloads);
    dl.remove(batchKey);
    for (final audioId in audioIdsInBatch) {
      dl.remove(audioId);
      _trackMeta.remove(audioId);
      _itemIdToStateKey.removeWhere((k, v) => v == audioId);
      // Limpiar state keys de video y letra
      dl.remove('${audioId}_video');
      dl.remove('${audioId}_lyrics');
      _itemIdToStateKey.removeWhere((k, v) => v == '${audioId}_video' || v == '${audioId}_lyrics');
    }
    _batchData.remove(batchKey);
    _batchTrackIds.remove(batchKey);
    emit(state.copyWith(downloads: dl));
  }

  /// Called from [dispatchDownloads] to dispatch audio/video/lyrics downloads
  /// for a single track. Updates state internally so `emit` is accessible.
  void dispatchSingleTrack({
    required Map<String, dynamic> commonMeta,
    required DownloadSettings settings,
    required String baseId,
    String? qualityOverride,
  }) async {
    if (!await _checkAllSessionsBeforeDownload()) return;
    final backend = sl<BackendService>();
    final itemId = commonMeta['item_id'] as String? ?? '';
    final audioKey = '${baseId}_audio';

    final dl = Map<String, DownloadStateData>.from(state.downloads);
    // Store by baseId so the feed can find it
    dl[baseId] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
    dl[audioKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
    if (itemId.isNotEmpty) _itemIdToStateKey[itemId] = baseId;
    // Store metadata so completedTracks returns a proper FeedItem
    // Use normalized ID for consistency with DB storage and deletion
    final normalizedTrackId = normalizeTrackId(itemId);
    _trackMeta[baseId] = _TrackInfo(
      normalizedTrackId,
      (commonMeta['track_title'] as String?) ?? '',
      commonMeta['artist_name'] as String?,
      commonMeta['cover_url'] as String?,
      (commonMeta['source'] as String?) ?? '',
    );
    _startedAt[baseId] = DateTime.now();
    emit(state.copyWith(downloads: dl));
    _ensurePolling();

    final audioStrategy = <String, dynamic>{
      ...commonMeta,
      'type': 'audio',
      'item_id': '${itemId}_audio',
      'quality': qualityOverride ?? settings.audioQuality,
    };
    _itemIdToStateKey['${itemId}_audio'] = baseId;
    backend.downloadByStrategy(jsonEncode(audioStrategy));

    if (settings.videoEnabled) {
      final videoKey = '${baseId}_video';
      dl[videoKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
      final videoStrategy = <String, dynamic>{
        ...commonMeta,
        'type': 'video',
        'item_id': '${itemId}_video',
        'quality': settings.videoQuality,
      };
      _itemIdToStateKey['${itemId}_video'] = videoKey;
      backend.downloadByStrategy(jsonEncode(videoStrategy));
    }

    if (settings.lyricsEnabled) {
      final lyricsKey = '${baseId}_lyrics';
      dl[lyricsKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
      _startedAt[lyricsKey] = DateTime.now();
      final lyricsStrategy = <String, dynamic>{
        ...commonMeta,
        'type': 'lyrics',
        'item_id': '${itemId}_lyrics',
        'source': settings.lyricsSource,
      };
      _itemIdToStateKey['${itemId}_lyrics'] = lyricsKey;
      backend.downloadByStrategy(jsonEncode(lyricsStrategy));
    }

    emit(state.copyWith(downloads: dl));
  }

  /// Deletes a single downloaded track by its ID and source.
  /// Uses multiple ID formats (stored from [meta], normalized, and original)
  /// to ensure the DB record is found regardless of how it was saved.
  Future<void> deleteTrackDownload(String trackId, String source) async {
    final normalizedId = normalizeTrackId(trackId);
    final audioId = 'track_${normalizedId}_$source';

    // Try all possible IDs the track could have been saved with
    final meta = _trackMeta[audioId];
    final idsToTry = <String>{};
    if (meta != null && meta.trackId.isNotEmpty) idsToTry.add(meta.trackId);
    idsToTry.add(normalizedId);
    if (trackId.isNotEmpty) idsToTry.add(trackId);
    await _downloadCache.deleteDownloadedTracks(idsToTry.toList());

    // Build file stems for disk cleanup: track IDs + lyrics + video
    final fileStems = <String>{...idsToTry};
    // lyrics_{sha1(TrackID)}.{lrc,txt} – try both original and normalized
    for (final id in {trackId, normalizedId, meta?.trackId ?? ''}) {
      if (id.isNotEmpty) {
        final hash = _sha1Hex(id);
        fileStems.add('lyrics_$hash');
      }
    }
    // video: {sanitizedArtist} - {sanitizedTitle}.mp4
    if (meta != null && meta.name.isNotEmpty && meta.artist != null && meta.artist!.isNotEmpty) {
      fileStems.add('${_sanitizeFilename(meta.artist!)} - ${_sanitizeFilename(meta.name)}');
    }
    sl<PlayerCubit>().removeLocalFilesProviderIds(fileStems.toList(), deleteFiles: true);
    sl<LibraryCache>().invalidateAll();

    // Clean up cover only if track is NOT also liked (unlike flow does the same)
    if (meta?.coverUrl != null && meta!.coverUrl!.isNotEmpty) {
      final likeCubit = sl<LikeCubit>();
      final isLiked = [meta.trackId, trackId, normalizedId]
          .any((id) => id.isNotEmpty && likeCubit.isItemIdLiked(id));
      if (!isLiked) {
        try { await _backend.deleteCover(meta.coverUrl!); } catch (_) {}
      }
    }

    final dl = Map<String, DownloadStateData>.from(state.downloads);
    final fps = Set<String>.from(state.downloadedFingerprints);
    dl.remove(audioId);
    _trackMeta.remove(audioId);

    // Limpiar state keys de video y letra
    final videoKey = '${audioId}_video';
    final lyricsKey = '${audioId}_lyrics';
    dl.remove(videoKey);
    dl.remove(lyricsKey);

    // Limpiar mapeo de item IDs del backend
    _itemIdToStateKey.removeWhere((k, v) =>
        v == audioId || v == videoKey || v == lyricsKey);

    // Limpiar fingerprints para que no reaparezca
    if (meta != null) {
      final fpName = meta.name.isNotEmpty ? meta.name : normalizedId;
      final fpArtist = meta.artist ?? '';
      fps.remove(fingerprintFromName(fpName, fpArtist));
    }

    // If this track belongs to a batch, update the batch state accordingly
    for (final batchKey in _batchTrackIds.keys.toList()) {
      final trackIds = _batchTrackIds[batchKey]!;
      if (trackIds.contains(audioId)) {
        trackIds.remove(audioId);
        if (trackIds.isNotEmpty) {
          int completed = 0;
          int stopped = 0;
          for (final id in trackIds) {
            final st = dl[id]?.state;
            if (st == DownloadState.completed) {
              completed++;
            } else if (st == DownloadState.none || st == DownloadState.interrupted) {
              stopped++;
            }
          }
          final total = trackIds.length;
          final allDone = (completed + stopped) >= total;
          dl[batchKey] = DownloadStateData(
            state: allDone
                ? (completed == total ? DownloadState.completed : DownloadState.none)
                : DownloadState.inProgress,
            progress: total > 0 ? completed / total : 0.0,
          );
          if (allDone && completed < total) _batchTrackIds.remove(batchKey);
        } else {
          dl.remove(batchKey);
          _batchTrackIds.remove(batchKey);
        }
        break;
      }
    }

    emit(state.copyWith(downloads: dl, downloadedFingerprints: fps));
  }

  /// Deletes a downloaded track even when the card was shown from a DIFFERENT
  /// extension than the one it was actually downloaded from. If the exact
  /// source-keyed entry isn't the download, it resolves the real entry by
  /// fingerprint (source-agnostic, same as the like) and deletes that.
  Future<void> deleteTrackResolved(FeedItem item) async {
    final baseId = 'track_${normalizeTrackId(item.id)}_${item.source ?? ''}';
    final haveExact = _trackMeta.containsKey(baseId) ||
        state.downloads[baseId]?.state == DownloadState.completed;
    if (haveExact) {
      await deleteTrackDownload(item.id, item.source ?? '');
      return;
    }
    final targetFp = fingerprintFromName(item.name, item.artists ?? '');
    _TrackInfo? match;
    for (final meta in _trackMeta.values) {
      if (fingerprintFromName(meta.name, meta.artist ?? '') == targetFp) {
        match = meta;
        break;
      }
    }
    if (match != null) {
      await deleteTrackDownload(match.trackId, match.source);
    }
  }

  /// Returns `FeedItem` for ALL completed track downloads (both batch and individual).
  /// Metadata comes from [_trackMeta] (persisted from DB + batch data).
  /// Falls back to key parsing only when metadata is missing (unlikely).
  List<FeedItem> get completedTracks {
    final result = <FeedItem>[];
    for (final entry in state.downloads.entries) {
      if (entry.value.state != DownloadState.completed) continue;
      if (!entry.key.startsWith('track_')) continue;
      // Skip subtask keys (_audio, _lyrics, _video) — only baseId has metadata
      if (entry.key.endsWith('_audio') || entry.key.endsWith('_lyrics') || entry.key.endsWith('_video')) continue;
      final meta = _trackMeta[entry.key];
      if (meta != null) {
        result.add(FeedItem(
          id: meta.trackId,
          type: 'track', name: meta.name,
          artists: meta.artist, coverUrl: meta.coverUrl,
          source: meta.source,
        ));
        continue;
      }
      // Fallback: parse key (only safe when ID has no underscores)
      final parts = entry.key.split('_');
      if (parts.length < 2) continue;
      final fallbackId = parts.sublist(1, parts.length - 1).join('_');
      final fallbackSrc = parts.last;
      // Try to find a fingerprint match among _trackMeta values
      String? fallbackName;
      String? fallbackArtist;
      String? fallbackCover;
      for (final m in _trackMeta.values) {
        if (m.trackId == fallbackId) {
          fallbackName = m.name;
          fallbackArtist = m.artist;
          fallbackCover = m.coverUrl;
          break;
        }
      }
      result.add(FeedItem(
        id: fallbackId,
        type: 'track', name: fallbackName ?? '', artists: fallbackArtist,
        coverUrl: fallbackCover, source: fallbackSrc,
      ));
    }
    return result;
  }

  /// Ensures [_trackMeta] has an entry for a rescued (already-downloaded) track.
  /// Preserves existing cover metadata if available, otherwise uses the batch data.
  void _ensureTrackMeta(String baseId, String normalizedId, Map<String, dynamic> trackMap, String source) {
    final existing = _trackMeta[baseId];
    if (existing != null && (existing.coverUrl?.isNotEmpty == true || existing.coverPath?.isNotEmpty == true)) {
      return;
    }
    _trackMeta[baseId] = _TrackInfo(
      normalizedId,
      (trackMap['track_title'] as String?) ?? '',
      trackMap['artist_name'] as String?,
      trackMap['cover_url'] as String?,
      source,
    );
  }

  /// Shared logic for dispatching a single track from an album/playlist batch.
  /// Extracts common metadata from [trackMap], then dispatches audio, video,
  /// and lyrics downloads via [dispatchDownloads].
  void _dispatchBatchTrack(
    Map<String, dynamic> trackMap,
    String trackId,
    String source,
    DownloadSettings settings, {
    String? qualityOverride,
  }) {
    final normalizedId = normalizeTrackId(trackId);
    final commonMeta = buildTrackMeta(
      trackId: trackId,
      trackTitle: (trackMap['track_title'] as String?) ?? '',
      artistName: (trackMap['artist_name'] as String?) ?? '',
      albumName: (trackMap['album_name'] as String?) ?? '',
      source: source,
      isrc: (trackMap['isrc'] as String?) ?? '',
      durationMs: (trackMap['duration_ms'] as int?) ?? 0,
      coverUrl: trackMap['cover_url'] as String?,
    );
    final baseId = 'track_${normalizedId}_$source';
    _trackMeta[baseId] = _TrackInfo(
      normalizedId,
      (trackMap['track_title'] as String?) ?? '',
      trackMap['artist_name'] as String?,
      trackMap['cover_url'] as String?,
      source,
    );
    dispatchDownloads(cubit: this, commonMeta: commonMeta, settings: settings, baseId: baseId, qualityOverride: qualityOverride);
  }
}





