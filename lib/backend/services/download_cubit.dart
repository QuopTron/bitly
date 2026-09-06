export '../cache/download_state.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import '../rpc/backend_service.dart';
import '../../frontend/shared/models/download_settings.dart';
import '../../frontend/shared/models/feed_models.dart';
import '../../frontend/shared/utils/download_strategy.dart';
import '../../injection.dart';
import '../cache/settings_cache.dart';
import '../cache/download_cache.dart';
import '../cache/detail_cache.dart';
import 'item_fingerprint.dart';
import 'stream_decrypt.dart';
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

/// A single track waiting in the sequential download queue.
class _QueuedTrack {
  final Map<String, dynamic> trackMap;
  final String trackId;
  final String source;
  final DownloadSettings settings;
  final String? qualityOverride;
  final String? batchKey;
  const _QueuedTrack(this.trackMap, this.trackId, this.source, this.settings,
      [this.qualityOverride, this.batchKey]);
}

/// Persistent metadata for a downloaded track (survives restart via DB).
class _TrackInfo {
  final String trackId;
  final String name;
  final String? artist;
  final String? coverUrl;
  final String? coverPath;
  final String source;
  /// ISRC when known at dispatch (survives empty provider ids — amazon/other
  /// providers resolve real ASINs by ISRC even when the feed track has no id).
  final String isrc;
  const _TrackInfo(this.trackId, this.name, this.artist, this.coverUrl, this.source, [this.coverPath, this.isrc = '']);
}

class _BatchMeta {
  final String name;
  final String itemType;
  final String itemId;
  final String source;
  final String coverUrl;
  final String coverPath;
  const _BatchMeta(this.name, this.itemType, this.itemId, this.source, {this.coverUrl = '', this.coverPath = ''});
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
  /// Batches already persisted as completed ({key, item_type, item_id, source})
  /// so [_finalizeCompletedBatch] only saves/invalidates once per batch.
  final Set<String> _batchCompletedSaved = {};
  /// Auto-retry counter per batch. When a batch reaches allDone with stragglers,
  /// we schedule a delayed retry up to [_maxBatchAutoRetries] times so the
  /// album/playlist eventually flips to green without manual intervention.
  final Map<String, int> _batchAutoRetryCount = {};
  static const int _maxBatchAutoRetries = 2;
  /// Track IDs that have already been retried and failed in this batch.
  /// Prevents infinite retry loops for tracks that consistently fail.
  final Map<String, Set<String>> _batchRetryFailed = {};
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
  /// Raw Go item IDs whose client-side decrypt FAILED. Without this the Go
  /// tracker (which reports completed items forever) triggers a new ffmpeg-kit
  /// attempt on every3s poll cycle, flooding the log with identical errors.
  final Set<String> _clientDecryptSkipped = {};
  /// Raw Go item IDs whose completion was already persisted (DB row, cover,
  /// fingerprint) on an earlier poll. The Go tracker reports completed items
  /// forever, so without this the 3s poller re-saves every finished download
  /// (saveCover RPC + DB upsert) on every cycle — a 42-track album means ~42
  /// redundant RPCs every 3 seconds indefinitely.
  final Set<String> _completedPersisted = {};
  /// Raw Go item IDs whose download was user-deleted. Prevents the 3s poll
  /// from resurrecting a deleted track before the Go cancel RPC takes effect.
  final Set<String> _pendingDeletes = {};
  /// Raw Go item IDs where a provider-race was already resolved (alternative
  /// playable file found). Without this, every 3s poll re-checks the same
  /// completed+encrypted tracker entries and floods the log.
  final Set<String> _raceResolved = {};
  /// Counter for completed-but-not-playable polls. When Go says 'completed'
  /// but the file isn't playable (e.g. SoundCloud .mp3 arrived before
  /// Apple Music .m4a), we wait up to 4 cycles (~12s) for the alt file.
  final Map<String, int> _completedNoFileCount = {};
  /// Track IDs whose files were confirmed missing from disk during _loadHistory.
  /// Prevents the infinite loop where _loadHistory re-processes the same
  /// missing-file entry every 10-30s.
  final Set<String> _loadHistorySkipped = {};

  /// Tracks that are being re-dispatched after a failed verification.
  /// Prevents infinite re-dispatch loops.
  final Set<String> _redownloadQueue = {};

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

  /// Decrypt failure counts per raw Go item id. A failed decrypt is retried on
  /// subsequent polls up to [_maxDecryptRetries] times before being marked
  /// skipped (transient ffmpeg-kit failures are common on emulators).
  final Map<String, int> _decryptFailCounts = {};
  static const int _maxDecryptRetries = 3;

  /// Poll cycles where Go reports `failed` + queue active + no file found.
  /// After [_maxFailedNoFilePolls] cycles (~15s at 3s intervals), the queue
  /// gives up and moves to the next track instead of looping forever.
  final Map<String, int> _failedNoFileCount = {};
  static const int _maxFailedNoFilePolls = 5;

  // ── Sequential download queue with batch awareness ──────────
  /// Global queue of batches. Batches are processed in FIFO order.
  /// Within each batch, tracks are sequential (1 at a time).
  final List<_QueuedTrack> _downloadQueue = [];
  bool _isProcessingQueue = false;
  Completer<void>? _currentTrackDone;
  String? _currentQueueTrackId;

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
        // ISRC fingerprint: the same recording from ANY provider carries the
        // same ISRC, so a track downloaded under one extension reads as
        // downloaded in every other extension even when name/artist differ.
        final isrc = (m['isrc'] ?? '').toString();
        if (isrc.isNotEmpty) {
          fps.add(fingerprintIsrc(isrc));
        }
        var src = (m['providerSource'] ?? m['service'] ?? '') as String;
        if (src.isEmpty) src = 'download';
        final rawId = (m['id'] ?? m['providerTrackId'] ?? '') as String;
        if (rawId.isNotEmpty) {
          // Normalizar el providerTrackId para que coincida con las keys
          // usadas por startAlbumDownload / startPlaylistDownload.
          final normalizedId = normalizeTrackId(rawId);
          final key = 'track_${normalizedId}_$src';
          // Skip tracks already confirmed missing — prevents infinite loop
          // where _loadHistory re-processes the same missing-file entry.
          if (_loadHistorySkipped.contains(key)) continue;
          _downloadedTrackIds.add(normalizedId);
          // Verify file exists AND is playable audio before marking as completed.
          // An encrypted Amazon FLAC file exists on disk but is NOT playable —
          // marking it completed would show a false green dot.
          final filePath = (m['file_path'] ?? '').toString();
          if (filePath.isNotEmpty) {
            final file = File(filePath);
            final fileExists = await file.exists().catchError((_) => false);
            if (!fileExists) {
              // File path from DB doesn't exist — try to find an alternative.
              // During decrypt, files may be renamed (e.g. .flac → .dec.flac)
              // or a racing provider may have saved a different extension.
              final altPath = await _findAlternativePlayableFile(key, filePath);
              if (altPath != null) {
                _log.i('[loadHistory] file missing at $filePath but found alternative: $altPath for $key');
                completedItems[key] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
                // Update the DB path to point to the actual file on disk.
                try {
                  await _downloadCache.updateFilePath(normalizedId, altPath);
                } catch (_) {}
              } else {
                completedItems[key] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
                _downloadedTrackIds.remove(normalizedId);
                _loadHistorySkipped.add(key);
                _log.w('[loadHistory] file missing on disk: $filePath for $key — removed from downloadedIds so re-download is possible');
              }
            } else if (!await _isDecodableAudioFile(file)) {
              // File exists but is not playable (encrypted DRM stream, corrupt, etc.)
              // Check for an alternative playable file before giving up.
              final altPath = await _findAlternativePlayableFile(key, filePath);
              if (altPath != null) {
                _log.i('[loadHistory] file not playable at $filePath but found alternative: $altPath for $key');
                completedItems[key] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
                try {
                  await _downloadCache.updateFilePath(normalizedId, altPath);
                } catch (_) {}
              } else {
                completedItems[key] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
                _downloadedTrackIds.remove(normalizedId);
                _loadHistorySkipped.add(key);
                _log.w('[loadHistory] file not playable: $filePath for $key — removed from downloadedIds so re-download is possible');
              }
            } else {
              completedItems[key] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
            }
          } else {
            completedItems[key] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
          }
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
            var batchCoverUrl = (m['cover_url'] ?? '') as String;
            var batchCoverPath = (m['cover_path'] ?? '') as String;
            // If DB batch has no covers (old data saved before schema v4),
            // try to adopt from the first track in _trackMeta.
            // track_ids are full state keys like "track_1470146792_apple-music"
            // (same format used as _trackMeta keys).
            if (batchCoverUrl.isEmpty && batchCoverPath.isEmpty) {
              final trackIdsRaw = (m['track_ids'] ?? '') as String;
              if (trackIdsRaw.isNotEmpty) {
                try {
                  final parsedIds = jsonDecode(trackIdsRaw) as List;
                  for (final tid in parsedIds) {
                    // Handle both old string format and new object format
                    String stateKey;
                    if (tid is Map<String, dynamic>) {
                      stateKey = (tid['id'] ?? '') as String;
                      // Also try embedded cover from enriched format
                      if (batchCoverUrl.isEmpty) {
                        batchCoverUrl = (tid['cover'] ?? '') as String;
                      }
                    } else {
                      stateKey = tid.toString();
                    }
                    final trackMeta = _trackMeta[stateKey];
                    if (trackMeta != null && (
                        (trackMeta.coverPath != null && trackMeta.coverPath!.isNotEmpty) ||
                        (trackMeta.coverUrl != null && trackMeta.coverUrl!.isNotEmpty))) {
                      batchCoverPath = trackMeta.coverPath ?? '';
                      batchCoverUrl = trackMeta.coverUrl ?? '';
                      break;
                    }
                  }
                } catch (_) {}
              }
            }
            _batchMeta[batchKey] = _BatchMeta(
              name, itemType, itemId, source,
              coverUrl: batchCoverUrl,
              coverPath: batchCoverPath,
            );
          }
          // Build reverse map: trackId → batchKey for cover backfill
          final trackIdsRaw = (m['track_ids'] ?? '') as String;
          if (trackIdsRaw.isNotEmpty) {
            try {
              final parsedIds = jsonDecode(trackIdsRaw) as List;
              // Also populate _batchTrackIds so batchCoverFor's runtime fallback
              // can search _trackMeta for covers even after app restart.
              final idStrings = <String>[];
              for (final entry in parsedIds) {
                if (entry is String) {
                  idStrings.add(entry);
                } else if (entry is Map<String, dynamic>) {
                  final id = (entry['id'] ?? '') as String;
                  if (id.isNotEmpty) idStrings.add(id);
                }
              }
              _batchTrackIds[batchKey] = idStrings;
              for (final stateKey in idStrings) {
                final ntid = normalizeTrackId(stateKey);
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

    // ── 3b. Backfill: for batches without covers, adopt first track's cover ──
    if (batchTrackMap.isNotEmpty) {
      final seenBatchKeys = <String>{};
      for (final entry in _trackMeta.entries) {
        final meta = entry.value;
        final batchKey = batchTrackMap[meta.trackId];
        if (batchKey == null || seenBatchKeys.contains(batchKey)) continue;
        final bm = _batchMeta[batchKey];
        if (bm == null || bm.coverUrl.isNotEmpty) {
          seenBatchKeys.add(batchKey);
          continue;
        }
        // Adopt cover from first track that has one
        final cover = (meta.coverPath != null && meta.coverPath!.isNotEmpty)
            ? meta.coverPath!
            : (meta.coverUrl ?? '');
        if (cover.isNotEmpty) {
          _batchMeta[batchKey] = _BatchMeta(
            bm.name, bm.itemType, bm.itemId, bm.source,
            coverUrl: bm.coverUrl.isNotEmpty ? bm.coverUrl : cover,
            coverPath: bm.coverPath.isNotEmpty ? bm.coverPath : cover,
          );
          changed = true;
        }
        seenBatchKeys.add(batchKey);
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

  /// Looks for a non-encrypted playable file (m4a, mp3) on disk for the
  /// same track when the encrypted FLAC decrypt failed. Uses the encrypted
  /// file's parent directory to scan for alternative playable files.
  Future<String?> _findAlternativePlayableFile(String stateKey, [String encryptedPath = '']) async {
    // stateKey: track_{normalizedId}_{source}
    final parts = stateKey.split('_');
    if (parts.length < 3) return null;
    final normId = parts.sublist(1, parts.length - 1).join('_');
    // Determine directory: use the encrypted file's parent, or fall back to
    // the configured download directory.
    String dirPath;
    if (encryptedPath.isNotEmpty) {
      dirPath = encryptedPath.substring(0, encryptedPath.lastIndexOf(Platform.pathSeparator));
    } else {
      // Fall back to the configured download directory
      try {
        final downloadDir = await sl<SettingsCache>().getDownloadPath();
        if (downloadDir == null || downloadDir.isEmpty) return null;
        dirPath = downloadDir;
      } catch (_) {
        return null;
      }
    }
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        _log.w('[findAlt] dir does not exist: $dirPath for $stateKey');
        return null;
      }
      for (final f in dir.listSync(followLinks: false)) {
        if (f is! File) continue;
        final filename = f.path.split(Platform.pathSeparator).last;
        if (!filename.toLowerCase().startsWith('${normId.toLowerCase()}_audio.')) continue;
        // Skip encrypted / tmp / non-playable files
        if (filename.contains('.tmp.') || filename.contains('.enc.')) continue;
        final ext = filename.substring(filename.lastIndexOf('.'));
        // Accept m4a, mp3, mp4, ogg, wav, opus as playable
        if ({'.m4a', '.mp3', '.mp4', '.ogg', '.wav', '.opus'}.contains(ext)) {
          if (f.existsSync() && f.lengthSync() > 1024) {
            // For .mp3 files, validate magic bytes to avoid returning
            // broken MPEG-TS files as "playable" alternatives.
            if (ext == '.mp3') {
              try {
                final raf = f.openSync(mode: FileMode.read);
                try {
                  final head = raf.readSync(4);
                  if (head.length < 4) continue;
                  final isID3 = head[0] == 0x49 && head[1] == 0x44 && head[2] == 0x33;
                  final isMPEG = head[0] == 0xFF && (head[1] & 0xE0) == 0xE0;
                  final isTS = head[0] == 0x47;
                  if (!isID3 && !isMPEG && !isTS) continue;
                } finally {
                  raf.closeSync();
                }
              } catch (_) {
                continue;
              }
            }
            return f.path;
          }
        }
        // Accept .flac (decrypted) and .dec.flac (ffmpeg-kit renamed)
        if ((ext == '.flac' || ext == '.dec.flac') && f.existsSync() && f.lengthSync() > 1024) {
          try {
            final raf = f.openSync(mode: FileMode.read);
            try {
              final head = raf.readSync(4);
              if (head.length >= 4 &&
                  head[0] == 0x66 && head[1] == 0x4C &&
                  head[2] == 0x61 && head[3] == 0x43) {
                return f.path;
              }
            } finally {
              raf.closeSync();
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      _log.w('[findAlt] error scanning dir $dirPath for $stateKey: $e');
    }
    _log.w('[findAlt] no playable file found for $stateKey in $dirPath (normId=$normId)');
    return null;
  }

  /// Decrypts an encrypted/DRM downloaded file (e.g. amazon FLAC with a
  /// mov_key) via ffmpeg-kit when the Go backend had no CLI ffmpeg to do it
  /// (Android). Writes the playable file next to the encrypted one, deletes
  /// the encrypted original on success and returns the decrypted path (or
  /// null on failure). Mirrors the streaming path in [PlayerCubit].
  Future<String?> _decryptDownloadedFile(String srcPath, String key, String ext, [String inputFormat = '']) async {
    final srcFile = File(srcPath);
    if (!await srcFile.exists()) return null;

    // Trust the file over the provider flag: the stream may be marked as
    // encrypted while actually being a plain, playable container (zarz serving
    // a plain FLAC with a stale key). Decrypting it as mov_key would always
    // fail with "moov atom not found".
    if (await _isPlainAudioFile(srcFile)) {
      _log.i('[DownloadCubit] marcado como encriptado pero es audio plano, se usa directo: $srcPath');
      return srcPath;
    }

    // Pass the original extension to decryptMovKeyFile so its full fallback
    // chain is available: .flac → .mp4 → .m4a → re-encode → nuclear. Remapping
    // .flac to .m4a here would skip the re-encode and nuclear fallbacks that
    // are gated on `preferredExt == '.flac'`, leaving us without a recovery
    // path when -c copy fails on FLAC-in-MP4 containers.
    _log.i('[DownloadCubit] decrypt src=$srcPath key=$key ext=$ext inputFormat=$inputFormat');
    final result = await decryptMovKeyFile(
      srcPath: srcPath,
      key: key,
      outputExtension: ext,
      inputFormat: inputFormat.isNotEmpty ? inputFormat : null,
    );

    if (result.success && result.filePath != null) {
      try {
        await srcFile.delete();
      } catch (_) {}
      return result.filePath;
    }
    _log.e('[DownloadCubit] ffmpeg-kit decrypt failed: ${result.output}');
    return null;
  }

  /// True when [f] starts with a plain audio container magic (FLAC/MP3/Ogg/WAV)
  /// instead of an MP4 box — i.e. it was never really an encrypted stream.
  Future<bool> _isPlainAudioFile(File f) async {
    try {
      final raf = await f.open();
      try {
        final head = await raf.read(4);
        final magic = String.fromCharCodes(head);
        return magic == 'fLaC' || magic == 'ID3' || magic == 'OggS' || magic == 'RIFF';
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

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
          // MPEG-TS container: SoundCloud HLS streams saved as .mp3 start
          // with the TS sync byte 0x47 instead of ID3/MPEG frame headers.
          // MPEG-TS packets are 188 bytes; the sync byte only appears at the
          // START of each packet, so checking magic[1]/magic[2] == 0x47 is
          // wrong — verify at offset 188 instead.
          if (magic[0] == 0x47) {
            return true;
          }
          return false;
        case 'wav':
          return magic[0] == 0x52 && magic[1] == 0x49 &&
              magic[2] == 0x46 && magic[3] == 0x46; // "RIFF"
        case 'ogg':
          return magic[0] == 0x4F && magic[1] == 0x67 &&
              magic[2] == 0x67 && magic[3] == 0x53; // "OggS"
        case 'opus':
          // Opus can be in Ogg container (OggS) or WebM/Matroska (0x1A 0x45 0xDF 0xA3)
          if (magic[0] == 0x4F && magic[1] == 0x67 &&
              magic[2] == 0x67 && magic[3] == 0x53) return true; // OggS
          if (magic[0] == 0x1A && magic[1] == 0x45 &&
              magic[2] == 0xDF && magic[3] == 0xA3) return true; // WebM/Matroska
          // Raw Opus: just accept if file is large enough (>10KB)
          return true;
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

  /// Re-starts history refresh with adaptive interval: 10s during active downloads.
  void _adjustHistoryRefreshRate() {
    final hasActive = state.downloads.values
        .any((d) => d.state == DownloadState.inProgress);
    final currentInterval = _historyTimer != null && _historyTimer!.isActive
        ? const Duration(seconds: 30)
        : Duration.zero;
    final desiredInterval = hasActive
        ? const Duration(seconds: 10)
        : const Duration(seconds: 30);
    if (currentInterval != desiredInterval) {
      _historyTimer?.cancel();
      _historyTimer = Timer.periodic(desiredInterval, (_) {
        _loadHistory().catchError((_) {});
      });
    }
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

            // Mark only the specific verification-needing track as interrupted,
            // not ALL in-progress tracks — other tracks may still be downloading
            // successfully and must not be disrupted.
            final rawId = entry.key.toString();
            final stateKey = _itemIdToStateKey[rawId] ?? rawId;
            final dl = Map<String, DownloadStateData>.from(state.downloads);
            if (dl[stateKey]?.state == DownloadState.inProgress) {
              dl[stateKey] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
              emit(state.copyWith(downloads: dl));
            }
            // Signal the queue so it doesn't block on a verification-stuck track
            if (!stateKey.endsWith('_lyrics') && !stateKey.endsWith('_video')) {
              _signalTrackDone(stateKey);
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
      // Snapshot before processing — used to detect queue modifications during
      // decrypt awaits or other async gaps inside this poll cycle.
      final initialPollDl = Map<String, DownloadStateData>.from(dl);
      final fps = Set<String>.from(state.downloadedFingerprints);
      bool changed = false;

      if (items.isNotEmpty) {
        hasLiveItems = true;
        _emptyProgressStreak = 0;

        for (final entry in items.entries) {
          final rawId = entry.key.toString();
          // Translate Go backend item_id to our state key
          final stateKey = _itemIdToStateKey[rawId] ?? rawId;
          // Skip entries that the user just deleted — the Go cancel RPC may
          // not have taken effect yet, preventing ghost resurrection.
          if (_pendingDeletes.contains(rawId)) continue;
          // Note: _currentQueueTrackId is NOT skipped here — the poll must
          // still process it to signal _signalTrackDone. Instead, the
          // 'mark interrupted' paths below check _currentQueueTrackId.
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
          final inputFormat = (p['inputFormat'] ?? '').toString();
          if (status == 'completed' || status == 'finalizing') {
            // Only persist to DB and save cover for the BASE (audio) completion.
            // Lyrics/video subtasks have their own completion events but their
            // stateKey is a subtask key (e.g. track_123_deezer_lyrics) where
            // _trackMeta has no entry — would produce a wrong trackId.
            final isSubTask = stateKey.endsWith('_lyrics') || stateKey.endsWith('_video');

            // Ya persistido en un poll anterior (Go reporta los items
            // completados indefinidamente): solo mantener el estado visual. El
            // path del tracker ya es el definitivo (Go marca "completed"
            // después del finalize), así que no hace falta re-guardar nada.
            //
            // Provider race fix: when SoundCloud completes first (non-encrypted)
            // and Amazon later overwrites the file with an encrypted FLAC, the
            // poll must re-process the item so the decrypt runs. Without this,
            // the encrypted file sits on disk but the track stays "completed"
            // with an unplayable file.
            if (!isSubTask && _completedPersisted.contains(rawId)) {
              // Fast path: provider race was already resolved on an earlier poll.
              if (_raceResolved.contains(rawId)) continue;
              if (encrypted && clientDecrypt && decKey.isNotEmpty &&
                  !_clientDecryptDone.contains(rawId) &&
                  !_clientDecryptSkipped.contains(rawId)) {
                // Before re-processing, check if the current file on disk is
                // still playable. If SoundCloud's .mp3 is still valid, don't
                // let Amazon's encrypted overwrite trigger a re-decrypt that
                // could downgrade the track to interrupted.
                if (outputPath.isNotEmpty) {
                  try {
                    final curFile = File(outputPath);
                    if (await curFile.exists() && await _isDecodableAudioFile(curFile)) {
                      _log.i('[poll] $rawId: provider race but current file is still playable — skipping re-process');
                      _raceResolved.add(rawId);
                      continue;
                    }
                  } catch (_) {}
                }
                // File was overwritten by a racing provider with an encrypted
                // version — but first check if an alternative playable file
                // exists before triggering a (potentially failing) decrypt cycle.
                final raceAlt = await _findAlternativePlayableFile(stateKey, outputPath);
                if (raceAlt != null) {
                  _log.i('[poll] $rawId: provider race but alternative file found: $raceAlt — keeping completed');
                  _raceResolved.add(rawId);
                  // Update the DB path so _verifyDownloadedFile in the queue
                  // doesn't fail when it checks the (now-stale) encrypted path.
                  try {
                    final meta = _trackMeta[stateKey];
                    final nid = meta != null && meta.trackId.isNotEmpty
                        ? meta.trackId : stateKey;
                    await _downloadCache.updateFilePath(nid, raceAlt);
                  } catch (_) {}
                  continue;
                }
                // No alternative — remove from persisted so decrypt runs below.
                _log.i('[poll] re-processing $rawId: file overwritten with encrypted version (provider race)');
                _completedPersisted.remove(rawId);
              } else {
                continue;
              }
            }

            // Encrypted/DRM download with a decryption key and no CLI ffmpeg
            // in the backend (Android): decrypt here via ffmpeg-kit — the
            // same step the streaming path performs — before persisting a
            // playable file. Otherwise the stored file is an unplayable
            // encrypted stream ("Error decoding audio" on every tap).
            var playablePath = outputPath;
            if (!isSubTask && playablePath.isNotEmpty && encrypted && clientDecrypt && decKey.isNotEmpty) {
              if (_clientDecryptDone.contains(rawId) || _clientDecryptSkipped.contains(rawId)) {
                // Already decrypted (or failed) on an earlier poll — never
                // re-process the same tracker entry.
              } else {
                // FAST PATH: Before attempting a potentially slow decrypt,
                // check if the file at outputPath is already playable
                // (e.g. Apple Music .m4a while encrypted flag is from Amazon).
                try {
                  final probeFile = File(playablePath);
                  if (await probeFile.exists() && await _isDecodableAudioFile(probeFile)) {
                    _log.i('[poll] $rawId: encrypted flag set but file is already playable: $playablePath - skipping decrypt');
                    _clientDecryptDone.add(rawId);
                    _decryptFailCounts.remove(rawId);
                  }
                } catch (_) {}
                // FAST PATH 2: If the encrypted file is NOT playable,
                // check if another provider already saved a playable file
                // (e.g. Apple Music .m4a, SoundCloud .mp3) BEFORE attempting
                // the slow ffmpeg-kit decrypt. This avoids 90s×3 decrypt
                // timeouts on emulators when a perfectly good alternative exists.
                if (!_clientDecryptDone.contains(rawId)) {
                  final altPath = await _findAlternativePlayableFile(stateKey, playablePath);
                  if (altPath != null) {
                    _log.i('[poll] $rawId: encrypted file not playable but alternative found: $altPath — skipping decrypt');
                    playablePath = altPath;
                    _clientDecryptDone.add(rawId);
                    _decryptFailCounts.remove(rawId);
                    try {
                      final meta = _trackMeta[stateKey];
                      final nid = meta != null && meta.trackId.isNotEmpty
                          ? meta.trackId : stateKey;
                      await _downloadCache.updateFilePath(nid, altPath);
                    } catch (_) {}
                  }
                }
                // SLOW PATH: Only attempt decrypt if no playable file found.
                if (!_clientDecryptDone.contains(rawId)) {
                  final decrypted = await _decryptDownloadedFile(playablePath, decKey, outExt, inputFormat)
                      .timeout(const Duration(seconds: 90), onTimeout: () {
                    _log.e('[poll] decrypt timed out after 90s for $rawId');
                    return null;
                  });
                  if (decrypted == null || decrypted.isEmpty) {
                    final attempts = (_decryptFailCounts[rawId] ?? 0) + 1;
                    _decryptFailCounts[rawId] = attempts;
                    _startedAt.remove(stateKey);
                    if (attempts < _maxDecryptRetries) {
                      _log.w('[poll] decrypt failed for $rawId (attempt $attempts/$_maxDecryptRetries), will retry next poll');
                      dl[stateKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.95);
                      changed = true;
                      continue;
                    }
                    // Retries exhausted — find alternative or flag interrupted.
                    if (!isSubTask) _signalTrackDone(stateKey);
                    _clientDecryptSkipped.add(rawId);
                    _decryptFailCounts.remove(rawId);
                    final altPath = await _findAlternativePlayableFile(stateKey, playablePath);
                    if (altPath != null) {
                      _log.i('[poll] decrypt failed for $rawId but alternative file exists: $altPath — keeping completed');
                      playablePath = altPath;
                      _completedPersisted.add(rawId);
                      try {
                        final meta = _trackMeta[stateKey];
                        final nid = meta != null && meta.trackId.isNotEmpty
                            ? meta.trackId : stateKey;
                        await _downloadCache.updateFilePath(nid, altPath);
                      } catch (_) {}
                    } else {
                      // Don't mark interrupted if the FIFO queue is waiting on
                      // this track — the new download is still in progress.
                      if (stateKey == _currentQueueTrackId) {
                        _log.i('[poll] $rawId: decrypt failed but queue is active — keeping inProgress');
                        dl[stateKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.95);
                      } else {
                        dl[stateKey] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
                        // Only show the ugly snackbar when the queue is NOT active
                        // for this track. When the queue is active, the track may
                        // still complete via an alternative provider.
                        _pendingDecryptError = 'decrypt';
                      }
                      changed = true;
                      continue;
                    }
                  } else {
                    _clientDecryptDone.add(rawId);
                    _decryptFailCounts.remove(rawId);
                    playablePath = decrypted;
                  }
                }
              }
            }

            // Before marking completed, verify the file on disk is actually
            // playable audio. Prevents false green dots when Go reports
            // completed but the file is corrupt / still encrypted.
            var filePlayable = true;
            if (!isSubTask && playablePath.isNotEmpty) {
              try {
                final pf = File(playablePath);
                if (await pf.exists()) {
                  filePlayable = await _isDecodableAudioFile(pf);
                  if (!filePlayable) {
                    _log.w('[poll] $rawId: Go says completed but file not playable: $playablePath');
                  }
                } else {
                  filePlayable = false;
                  _log.w('[poll] $rawId: Go says completed but file missing: $playablePath');
                }
              } catch (_) {}
            }
            if (!filePlayable) {
              // Go's tracker stores .tmp.XXX as outputPath before finalize
              // renames to .XXX. Check the non-tmp path first.
              if (playablePath.isNotEmpty) {
                final tmpIdx = playablePath.indexOf('.tmp.');
                if (tmpIdx >= 0) {
                  final nonTmpPath = playablePath.replaceFirst('.tmp.', '.');
                  try {
                    final ntFile = File(nonTmpPath);
                    if (await ntFile.exists() && await _isDecodableAudioFile(ntFile)) {
                      _log.i('[poll] $rawId: .tmp file missing but non-tmp exists: $nonTmpPath — using it');
                      playablePath = nonTmpPath;
                      filePlayable = true;
                      _completedNoFileCount.remove(rawId);
                      try {
                        final meta = _trackMeta[stateKey];
                        final nid = meta != null && meta.trackId.isNotEmpty ? meta.trackId : stateKey;
                        await _downloadCache.updateFilePath(nid, nonTmpPath);
                      } catch (_) {}
                    }
                  } catch (_) {}
                }
              }
            }
            if (!filePlayable) {
              // File not playable — check for alternative files from other
              // providers before flagging as interrupted. A racing provider
              // (e.g. Apple Music .m4a or a decrypted Amazon .flac) may have
              // saved a valid file alongside the broken one.
              final altPath = await _findAlternativePlayableFile(stateKey, playablePath);
              if (altPath != null) {
                _log.i('[poll] $rawId: file not playable but alternative exists: $altPath — using it');
                playablePath = altPath;
                filePlayable = true;
                _completedNoFileCount.remove(rawId);
                // Update DB path so _verifyDownloadedFile in the queue
                // doesn't fail when it checks the broken path.
                try {
                  final meta = _trackMeta[stateKey];
                  final nid = meta != null && meta.trackId.isNotEmpty
                      ? meta.trackId : stateKey;
                  await _downloadCache.updateFilePath(nid, altPath);
                } catch (_) {}
              }
            }
            if (filePlayable) {
              dl[stateKey] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
            } else {
              if (stateKey == _currentQueueTrackId) {
                _log.i('[poll] $rawId: file not playable but queue is active — keeping inProgress');
                dl[stateKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.95);
              } else {
                dl[stateKey] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
                // Only show snackbar when queue is no longer active
                _pendingDecryptError = 'decrypt';
              }
            }
            changed = true;
            // Also update sibling subtask keys (audio/lyrics/video) if they exist
            final audioKey = '${stateKey}_audio';
            if (dl.containsKey(audioKey)) {
              dl[audioKey] = filePlayable
                  ? const DownloadStateData(state: DownloadState.completed, progress: 1.0)
                  : const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
            }
            final lyricsKey = '${stateKey}_lyrics';
            if (dl.containsKey(lyricsKey)) {
              dl[lyricsKey] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
            }
            final videoKey = '${stateKey}_video';
            if (dl.containsKey(videoKey)) {
              dl[videoKey] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
            }

            // Signal the sequential queue that this track finished
            // BUT: if the file exists but isn't playable yet (e.g. SoundCloud
            // .mp3 arrived but Apple Music .m4a hasn't been finalized), don't
            // signal — keep polling so the .m4a has time to appear.
            if (!isSubTask) {
              if (filePlayable) {
                _signalTrackDone(stateKey);
              } else {
                // Counter: give Apple Music etc. time to finalize the .m4a
                final noFileCount = _completedNoFileCount[rawId] ?? 0;
                _completedNoFileCount[rawId] = noFileCount + 1;
                if (noFileCount >= 4) {
                  // ~12s elapsed — give up, mark interrupted
                  _log.w('[poll] $rawId: file not playable after ${noFileCount + 1} polls, giving up');
                  _completedNoFileCount.remove(rawId);
                  dl[stateKey] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
                  changed = true;
                  _completedPersisted.add(rawId);
                  _signalTrackDone(stateKey);
                } else {
                  _log.i('[poll] $rawId: file not playable, waiting for alt (${noFileCount + 1}/4)');
                }
              }
            }

            if (!isSubTask) {
              final meta = _trackMeta[stateKey];
              var trackId = meta?.trackId ?? (stateKey.startsWith('track_') && stateKey.length > 6
                  ? stateKey.substring(6, stateKey.lastIndexOf('_'))
                  : rawId);
              final src = meta?.source ?? (stateKey.contains('_') ? stateKey.split('_').last : '');

              // A feed track may arrive with an empty provider id (but a valid
              // ISRC) — amazon/others still resolve a real file by ISRC. Fall
              // back to the ISRC so we persist an identifiable, deletable,
              // playable row instead of an all-empty `unknown` entry.
              final isrc = meta?.isrc ?? '';
              if (trackId.isEmpty && isrc.isNotEmpty) {
                trackId = isrc;
              }

              // Save cover locally for offline persistence (like liked tracks).
              // saveCover returns the absolute path so covers also render on
              // platforms without the desktop HTTP server (Android).
              final trackCoverUrl = meta?.coverUrl;
              String? coverPath;
              if (trackCoverUrl != null && trackCoverUrl.isNotEmpty) {
                for (var attempt = 0; attempt < 3; attempt++) {
                  try {
                    final coverPathResult = await _backend.saveCover(trackCoverUrl);
                    if (coverPathResult != null && coverPathResult.isNotEmpty) {
                      coverPath = coverPathResult;
                      break;
                    }
                  } catch (_) {
                    coverPath = null;
                  }
                  if (attempt < 2) {
                    await Future<void>.delayed(Duration(seconds: 1 << attempt));
                  }
                }
                if (coverPath != null && coverPath.isNotEmpty && meta != null) {
                  _trackMeta[stateKey] = _TrackInfo(
                    meta.trackId, meta.name, meta.artist, meta.coverUrl, meta.source, coverPath,
                  );
                }
              }

              unawaited(_downloadCache.saveDownloadedTrack(
                id: trackId,
                trackName: trackName.isNotEmpty ? trackName : (isrc.isNotEmpty ? isrc : rawId),
                artistName: artistName.isNotEmpty ? artistName : '',
                isrc: isrc.isNotEmpty ? isrc : null,
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

              final fpName = trackName.isNotEmpty ? trackName : (isrc.isNotEmpty ? isrc : rawId);
              final fpArtist = trackName.isNotEmpty ? artistName : '';
              fps.add(fingerprintFromName(fpName, fpArtist));
              _completedPersisted.add(rawId);

              // Immediately register the file in the player's local files map
              // so it can play from disk without waiting for a DB reload.
              if (playablePath.isNotEmpty) {
                sl<PlayerCubit>().registerLocalFile(
                  trackId: trackId,
                  filePath: playablePath,
                  providerTrackId: rawId.endsWith('_audio')
                      ? rawId.substring(0, rawId.length - 6)
                      : rawId.endsWith('_lyrics')
                          ? rawId.substring(0, rawId.length - 7)
                          : rawId.endsWith('_video')
                              ? rawId.substring(0, rawId.length - 6)
                              : rawId,
                  trackName: trackName.isNotEmpty ? trackName : null,
                  artistName: artistName.isNotEmpty ? artistName : null,
                  isrc: isrc.isNotEmpty ? isrc : null,
                );
              }
            }
            _startedAt.remove(stateKey);
            changed = true;
          } else if (status == 'downloading' || status == 'preparing') {
            // Don't resurrect tracks that were marked interrupted by the hard
            // timeout or user cancellation — the Go tracker may still show them
            // as 'downloading' because the goroutine hasn't finished yet.
            final curState = dl[stateKey]?.state;
            // Don't overwrite completed tracks — a losing provider (e.g.
            // Amazon encrypted .flac) may still report 'downloading' after
            // the winning provider (Apple Music .m4a) already finished.
            if (curState != DownloadState.interrupted && curState != DownloadState.completed) {
              dl[stateKey] = DownloadStateData(state: DownloadState.inProgress, progress: progress.toDouble());
              changed = true;
            }
          } else if (status == 'failed' || status == 'cancelled') {
            // Skip if already processed on an earlier poll cycle.
            if (_completedPersisted.contains(rawId)) continue;
            if (stateKey == _currentQueueTrackId) {
              // Go reports failed but the FIFO queue is still waiting.
              // Check if a provider already wrote a playable file on disk.
              //
              // Fast path 1: if outputPath points to an existing playable file,
              // persist it directly without scanning the directory.
              String? playableAlt;
              if (outputPath.isNotEmpty) {
                try {
                  final opFile = File(outputPath);
                  if (await opFile.exists() && await _isDecodableAudioFile(opFile)) {
                    playableAlt = outputPath;
                    _log.i('[poll] $rawId: Go reports $status but outputPath is playable: $outputPath — persisting');
                  }
                } catch (_) {}
                // Fast path 1b: outputPath might be .tmp.XXX (before finalize rename).
                // Try the non-tmp version.
                if (playableAlt == null && outputPath.contains('.tmp.')) {
                  try {
                    final nonTmp = outputPath.replaceFirst('.tmp.', '.');
                    final ntFile = File(nonTmp);
                    if (await ntFile.exists() && await _isDecodableAudioFile(ntFile)) {
                      playableAlt = nonTmp;
                      _log.i('[poll] $rawId: Go reports $status but non-tmp path playable: $nonTmp — persisting');
                    }
                  } catch (_) {}
                }
              }
              // Fast path 2: scan the directory for an alternative playable file.
              if (playableAlt == null) {
                playableAlt = await _findAlternativePlayableFile(stateKey, outputPath);
              }
              if (playableAlt != null) {
                _failedNoFileCount.remove(rawId);
                _log.i('[poll] $rawId: Go reports $status but alternative found: $playableAlt — persisting as completed');
                try {
                  final meta = _trackMeta[stateKey];
                  final nid = meta != null && meta.trackId.isNotEmpty ? meta.trackId : stateKey;
                  // Use saveDownloadedTrack (INSERT OR REPLACE) to ensure
                  // the row exists — updateFilePath would silently no-op if
                  // no row exists yet (first download, poll persisted before
                  // the normal completed path ran).
                  await _downloadCache.saveDownloadedTrack(
                    id: nid, trackName: meta?.name ?? '', artistName: meta?.artist ?? '',
                    filePath: playableAlt, service: meta?.source ?? '',
                  );
                } catch (_) {}
                _completedPersisted.add(rawId);
                dl[stateKey] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
                changed = true;
                _signalTrackDone(stateKey);
              } else {
                // No playable file yet — a provider may still be writing.
                // Track consecutive "no file" cycles to avoid infinite loop.
                final count = (_failedNoFileCount[rawId] ?? 0) + 1;
                _failedNoFileCount[rawId] = count;
                if (count >= _maxFailedNoFilePolls) {
                  // Exhausted retries — no provider produced a playable file.
                  _log.w('[poll] $rawId: Go reports $status after $count polls — no file found, giving up');
                  _failedNoFileCount.remove(rawId);
                  dl[stateKey] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
                  _completedPersisted.add(rawId);
                  _signalTrackDone(stateKey);
                } else {
                  _log.i('[poll] $rawId: Go reports $status but queue is active — no playable file found yet ($count/$_maxFailedNoFilePolls), keeping inProgress (outputPath=$outputPath)');
                  dl[stateKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.95);
                }
                changed = true;
              }
            } else {
              dl[stateKey] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
              _startedAt.remove(stateKey);
              _signalTrackDone(stateKey);
            }
          }
        }
      }

      // ── 2. Recompute batch (album/playlist) aggregate progress ──
      for (final batchKey in _batchTrackIds.keys.toList()) {
        final trackIds = _batchTrackIds[batchKey]!;
        if (trackIds.isEmpty) { _batchTrackIds.remove(batchKey); continue; }

        // Skip batches that are already completed — shared tracks being
        // re-downloaded by another playlist should not regress the state.
        final prevBatchState = dl[batchKey]?.state;
        if (prevBatchState == DownloadState.completed) continue;

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
          if (completed == total) {
            dl[batchKey] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
            await _finalizeCompletedBatch(batchKey, trackIds);
            _batchTrackIds.remove(batchKey);
            _batchAutoRetryCount.remove(batchKey);
            _batchRetryFailed.remove(batchKey);
          } else {
            // Incompleto: mantener el batch vivo para que completar el/los
            // rezagados más tarde (manual o vía retry) pueda elevarlo a
            // "completed" y persistirlo. Auto-retry up to _maxBatchAutoRetries
            // times so the batch flips to green without manual intervention.
            dl[batchKey] = DownloadStateData(state: DownloadState.none, progress: progress);
            final retryCount = _batchAutoRetryCount[batchKey] ?? 0;
            // Collect failed track IDs for this batch
            final failedIds = <String>{};
            for (final id in trackIds) {
              final st = dl[id]?.state;
              if (st == DownloadState.interrupted || st == DownloadState.none) {
                failedIds.add(id);
              }
            }
            // Only retry if there are failed tracks NOT already in _batchRetryFailed
            final alreadyFailed = _batchRetryFailed[batchKey] ?? {};
            final newFailures = failedIds.difference(alreadyFailed);
            if (retryCount < _maxBatchAutoRetries && _batchData.containsKey(batchKey) && newFailures.isNotEmpty) {
              _batchAutoRetryCount[batchKey] = retryCount + 1;
              _batchRetryFailed[batchKey] = alreadyFailed.union(newFailures);
              _log.i('[batch] auto-retry #$retryCount for $batchKey (${newFailures.length} new failures, ${alreadyFailed.length} previously failed)');
              final bk = batchKey;
              Future.delayed(const Duration(seconds: 15), () {
                if (_batchTrackIds.containsKey(bk) && _batchData.containsKey(bk)) {
                  retryFailedBatchTracks(bk);
                }
              });
            }
          }
          changed = true;
        } else if (completed > 0) {
          dl[batchKey] = DownloadStateData(state: DownloadState.inProgress, progress: progress);
          changed = true;
        }
      }

      if (changed) {
        // Merge poll changes into the CURRENT state so we don't overwrite
        // states modified by _processDownloadQueue during async gaps (e.g.
        // decrypt await).  Only apply our change when the key's state hasn't
        // been touched since the snapshot we took at the start of this poll.
        final currentDl = Map<String, DownloadStateData>.from(state.downloads);
        for (final entry in dl.entries) {
          final current = currentDl[entry.key];
          final initial = initialPollDl[entry.key];
          // Apply if: key is new, or current state still matches our snapshot
          // (meaning the queue didn't modify it while we were processing).
          if (initial == null ||
              current == null ||
              current.state == initial.state) {
            currentDl[entry.key] = entry.value;
          }
        }
        emit(state.copyWith(
          downloads: currentDl,
          downloadedFingerprints: fps,
          decryptError: _pendingDecryptError,
        ));
        _pendingDecryptError = null;
        _adjustHistoryRefreshRate();
      }

      // ── 3. Timeout detection ──────────────────────────────
      // If we have in-progress items but no live progress from backend
      // for ~12s (4 polls), mark them as interrupted — BUT never kill
      // the track the FIFO queue is currently waiting on (it has its
      // own 300s timeout and may be in decrypt phase).
      final hasInProgress = state.downloads.values
          .any((d) => d.state == DownloadState.inProgress);
      if (hasInProgress && !hasLiveItems) {
        _emptyProgressStreak++;
        if (_emptyProgressStreak >= 6) {
          final dl = Map<String, DownloadStateData>.from(state.downloads);
          bool changed = false;
          for (final key in dl.keys) {
            if (dl[key]!.state == DownloadState.inProgress) {
              // CRITICAL: never kill the track the FIFO queue is waiting on
              if (key == _currentQueueTrackId) continue;
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

      // ── 4. Hard timeout: mark items stuck over 120s as interrupted ──
      // Skip the current queue track — it has its own 300s timeout in
      // _processDownloadQueue. Only orphaned tracks get hard-timed-out.
      final now = DateTime.now();
      final hardDl = Map<String, DownloadStateData>.from(state.downloads);
      bool hardTimedOut = false;
      for (final id in _startedAt.keys.toList()) {
        if (hardDl[id]?.state != DownloadState.inProgress) {
          _startedAt.remove(id);
          continue;
        }
        // Skip the track currently being processed by the FIFO queue
        if (id == _currentQueueTrackId) continue;
        if (now.difference(_startedAt[id]!) > const Duration(seconds: 120)) {
          // Check the live tracker map for this item's current status
          String? liveStatus;
          // Reverse-lookup: stateKey → raw Go tracker ID
          for (final entry in _itemIdToStateKey.entries) {
            if (entry.value == id) {
              final rawItem = items[entry.key];
              if (rawItem is Map) {
                liveStatus = _statusOf(rawItem as Map<String, dynamic>);
              }
              break;
            }
          }
          if (liveStatus == 'completed') {
            _log.i('[poll] hard-timeout for $id but Go reports completed — marking completed');
            hardDl[id] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
            _startedAt.remove(id);
            hardTimedOut = true;
            if (!id.endsWith('_lyrics') && !id.endsWith('_video')) {
              _signalTrackDone(id);
            }
          } else if (liveStatus == 'failed' || liveStatus == 'cancelled') {
            _log.i('[poll] hard-timeout for $id but Go reports $liveStatus — marking interrupted');
            hardDl[id] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
            _startedAt.remove(id);
            hardTimedOut = true;
            if (!id.endsWith('_lyrics') && !id.endsWith('_video')) {
              _signalTrackDone(id);
            }
          } else if (liveStatus == 'downloading' || liveStatus == 'preparing') {
            // Go is still actively working on this item — extend the timeout
            _log.d('[poll] hard-timeout for $id but Go still reports $liveStatus — extending');
            _startedAt[id] = now; // reset the timer
          } else {
            // Item gone from tracker — download completed while poll was busy.
            // Check for a playable file on disk.
            final altPath = await _findAlternativePlayableFile(id);
            if (altPath != null) {
              _log.i('[poll] hard-timeout for $id but file exists on disk: $altPath — marking completed');
              hardDl[id] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
              _startedAt.remove(id);
              hardTimedOut = true;
              if (!id.endsWith('_lyrics') && !id.endsWith('_video')) {
                _signalTrackDone(id);
              }
            } else {
              _log.i('[poll] hard-timeout for $id — no tracker, no file — marking interrupted');
              hardDl[id] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
              _startedAt.remove(id);
              hardTimedOut = true;
              if (!id.endsWith('_lyrics') && !id.endsWith('_video')) {
                _signalTrackDone(id);
              }
            }
          }
        }
      }
      if (hardTimedOut) emit(state.copyWith(downloads: hardDl));

      // Clean up _pendingDeletes for tracker IDs that Go no longer reports
      // (confirming the cancel RPC took effect). This allows future
      // re-downloads of the same track.
      if (_pendingDeletes.isNotEmpty) {
        if (items.isNotEmpty) {
          final liveIds = items.keys.toSet();
          _pendingDeletes.removeWhere((id) => !liveIds.contains(id));
        } else {
          // Go reports nothing → all cancels took effect
          _pendingDeletes.clear();
        }
      }
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
        try {
          // Check for a pending verification URL; if none, trigger the
          // Cloudflare challenge for this provider.
          var url = await _backend.getPendingVerificationUrl(extId);
          _log.i('[$extId] getPendingVerificationUrl -> "$url"');
          if (url.isEmpty) {
            url = await _backend.triggerExtensionVerification(extId);
            _log.i('[$extId] triggerExtensionVerification -> "$url"');
          }
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
        } catch (e) {
          _log.w('[$extId] verification error: $e');
        }
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

  /// Returns cached track metadata (name, artist, cover) for a state key,
  /// or null if not available. Used by detail pages to resolve names
  /// from batches when API data isn't loaded yet.
  ({String name, String artist, String cover})? trackMetaFor(String stateKey) {
    final m = _trackMeta[stateKey];
    if (m == null) return null;
    return (
      name: m.name,
      artist: m.artist ?? '',
      cover: m.coverUrl ?? m.coverPath ?? '',
    );
  }

  /// Find the source used to download a batch (album/playlist).
  /// Checks _batchMeta first, then scans state.downloads keys.
  /// Returns empty string if no batch found.
  String findBatchSource(String type, String itemId) {
    final normId = normalizeTrackId(itemId);
    // 1) Check _batchMeta for exact match
    for (final entry in _batchMeta.entries) {
      final key = entry.key; // e.g. 'playlist_normId_ytmusic-spotiflac'
      if (key.startsWith('${type}_') && key.contains('_${normId}_')) {
        return entry.value.source;
      }
    }
    // 2) Scan state.downloads for batch key
    for (final key in state.downloads.keys) {
      if (key.startsWith('${type}_') && key.contains('_${normId}_')) {
        // Extract source from key: type_normId_source
        final parts = key.split('_');
        if (parts.length >= 3) return parts.last;
      }
    }
    // 3) Check DB for completed batches
    return '';
  }

  /// Persists a fully-completed album/playlist batch and refreshes the library
  /// cache. Idempotent per batch (guarded by [_batchCompletedSaved]) so a
  /// straggler completed manually after the batch "looked" finished only saves
  /// once, and on restart the batch is restored as green instead of stuck.
  Future<void> _finalizeCompletedBatch(String batchKey, List<String> trackIds) async {
    if (_batchCompletedSaved.contains(batchKey)) return;
    _batchCompletedSaved.add(batchKey);
    final parts = batchKey.split('_');
    if (parts.length < 2) return;
    final itemType = parts[0];
    final src = parts.last;
    final itemId = parts.sublist(1, parts.length - 1).join('_');
    final batchData = _batchData[batchKey];
    final batchName = (batchData?.tracks.isNotEmpty == true)
        ? (batchData!.tracks.first['album_name'] as String? ?? '')
        : '';
    // Extract cover URL from the first track's metadata for the album/playlist.
    final batchCover = (batchData?.tracks.isNotEmpty == true)
        ? (batchData!.tracks.first['cover_url'] as String? ?? '')
        : '';
    // Save album/playlist cover locally for offline persistence.
    // Retry 3 times with exponential backoff (same as single-track covers)
    // so a transient network blip doesn't lose the cover.
    String batchCoverPath = '';
    if (batchCover.isNotEmpty) {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final saved = await _backend.saveCover(batchCover);
          if (saved != null && saved.isNotEmpty) {
            batchCoverPath = saved;
            break;
          }
        } catch (_) {}
        if (attempt < 2) {
          await Future<void>.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    _batchMeta[batchKey] = _BatchMeta(batchName, itemType, itemId, src,
        coverUrl: batchCover, coverPath: batchCoverPath);
    await _downloadCache.saveDownloadedBatch(
      batchKey, itemType, itemId, src, batchName,
      trackIds: trackIds,
      coverUrl: batchCover,
      coverPath: batchCoverPath,
    );
    sl<LibraryCache>().invalidateAll();
    // Invalidate detail cache so album/playlist pages reload with fresh data
    final detailCache = sl<DetailCache>();
    if (itemType == 'album') {
      await detailCache.invalidateAlbum(itemId);
    } else if (itemType == 'playlist') {
      await detailCache.invalidatePlaylist(itemId);
    }
  }

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

  /// Returns the list of track state keys that belong to a batch.
  List<String> batchTrackIdsFor(String batchKey) => _batchTrackIds[batchKey] ?? const [];

  /// Returns the best cover path for a batch key (album/playlist):
  /// local path first, then network URL, or empty string if not available.
  String batchCoverFor(String batchKey) {
    final meta = _batchMeta[batchKey];
    if (meta != null) {
      if (meta.coverPath.isNotEmpty) return meta.coverPath;
      if (meta.coverUrl.isNotEmpty) return meta.coverUrl;
    }
    // Runtime fallback: search _trackMeta for the first track belonging
    // to this batch using _batchTrackIds which maps batch → track state keys.
    final trackIds = _batchTrackIds[batchKey];
    if (trackIds != null && trackIds.isNotEmpty) {
      for (final tid in trackIds) {
        final tm = _trackMeta[tid];
        if (tm != null) {
          if (tm.coverPath != null && tm.coverPath!.isNotEmpty) return tm.coverPath!;
          if (tm.coverUrl != null && tm.coverUrl!.isNotEmpty) return tm.coverUrl!;
        }
      }
    }
    return '';
  }

  /// Returns true if there is a completed batch (album/playlist) with the
  /// given [type] and normalized [id] in the in-memory download state.
  bool isCollectionDownloaded(String type, String id) {
    final normalized = normalizeTrackId(id);
    for (final entry in state.downloads.entries) {
      if (entry.value.state != DownloadState.completed) continue;
      if (!entry.key.startsWith('${type}_')) continue;
      final parts = entry.key.split('_');
      if (parts.length < 3) continue;
      final entryId = parts.sublist(1, parts.length - 1).join('_');
      if (normalizeTrackId(entryId) == normalized) return true;
    }
    return false;
  }

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
      // Pre-seed as queued; _processDownloadQueue flips it to inProgress when
      // the track reaches the front of the FIFO row.
      dl[audioId] = const DownloadStateData(state: DownloadState.queued, progress: 0.0);
      // Clear ALL poll state so the retried download processes from scratch.
      // Without this, _completedPersisted makes the poll skip the new tracker
      // entry (same rawId), and _redownloadQueue prevents re-dispatch on
      // verify failure.
      final retryRawId = '${normalizedTid}_audio';
      _clientDecryptSkipped.remove(retryRawId);
      _clientDecryptDone.remove(retryRawId);
      _decryptFailCounts.remove(retryRawId);
      _completedPersisted.remove(retryRawId);
      _raceResolved.remove(retryRawId);
      _redownloadQueue.remove(audioId);
      // Route through the global FIFO queue — dispatching directly here used
      // to fire retried tracks in parallel, breaking the one-at-a-time order.
      _downloadQueue.add(_QueuedTrack(t, tid, data.source, data.settings, data.qualityOverride, batchKey));
    }

    _batchTrackIds[batchKey] = audioIds;

    // Reset batch state to inProgress (dl already has the pre-seeded tracks)
    dl[batchKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
    emit(state.copyWith(downloads: dl));
    _processDownloadQueue();
  }

  Future<bool> _checkAllSessionsBeforeDownload() async {
    return true;
  }

  /// Check that the download folder is accessible (exists, is a directory,
  /// and is writable). When the folder is lost (e.g. SAF grant revoked,
  /// directory deleted, permission denied), emits a state that triggers the
  /// UI recovery dialog. Returns true if the folder is OK.
  Future<bool> _checkDownloadFolder() async {
    final path = await sl<SettingsCache>().getDownloadPath();
    if (path == null || path.isEmpty) {
      emit(state.copyWith(folderLost: true));
      return false;
    }
    final dir = Directory(path);
    try {
      if (!await dir.exists()) {
        _log.w('[download] folder lost — path does not exist: $path');
        emit(state.copyWith(folderLost: true));
        return false;
      }
      // Try creating a temp file to verify write access.
      final testFile = File('$path/.access_test');
      await testFile.writeAsString('ok');
      await testFile.delete();
    } catch (e) {
      _log.w('[download] folder lost — cannot access $path: $e');
      emit(state.copyWith(folderLost: true));
      return false;
    }
    return true;
  }

  /// Clear the folder-lost flag after the user re-selects the download folder.
  void acknowledgeFolderRestored() {
    emit(state.copyWith(clearFolderLost: true));
  }

  /// Starts downloading a single track through the FIFO queue.
  /// The track is enqueued and processed in order — it will NOT run
  /// in parallel with any ongoing batch (album/playlist) downloads.
  void startDownload(String id, {Map<String, dynamic>? strategy}) async {
    if (state.downloads[id]?.state == DownloadState.inProgress) return;
    if (state.downloads[id]?.state == DownloadState.completed) return;
    // Check if track ID is already in download history (skip re-download)
    final s = strategy ?? {'type': 'audio'};
    final trackId = (s['track_id'] ?? s['item_id'] ?? '').toString();
    if (trackId.isNotEmpty) {
      final normalizedId = normalizeTrackId(trackId);
      if (_downloadedTrackIds.contains(normalizedId)) {
        _log.i('[startDownload] skip duplicate by ID: $normalizedId');
        return;
      }
    }
    // Check fingerprint for source-agnostic duplicate detection
    final trackName = (s['track_title'] ?? '') as String;
    final artistName = (s['artist_name'] ?? '') as String;
    if (trackName.isNotEmpty && state.downloadedFingerprints.contains(
        fingerprintFromName(trackName, artistName))) {
      _log.i('[startDownload] skip duplicate by fingerprint: $trackName by $artistName');
      return;
    }
    if (!await _checkDownloadFolder()) return;
    if (!await _checkAllSessionsBeforeDownload()) return;
    // Allow retry of a previously failed client-side decrypt by clearing
    // the skip marker for the item being re-dispatched.
    final retryItemId = (s['item_id'] ?? s['track_id'] ?? '').toString();
    if (retryItemId.isNotEmpty) _clientDecryptSkipped.remove(retryItemId);

    // Route through the FIFO queue — dispatching directly used to fire
    // single tracks in parallel with batch downloads, breaking the
    // one-at-a-time order and showing multiple orange dots.
    final source = (s['source'] ?? '').toString();
    final dl = Map<String, DownloadStateData>.from(state.downloads);
    dl[id] = const DownloadStateData(state: DownloadState.queued, progress: 0.0);
    emit(state.copyWith(downloads: dl));
    _log.i('[startDownload] enqueuing single track: $id source=$source');
    _downloadQueue.add(_QueuedTrack(s, trackId, source, const DownloadSettings(), null, '_singles'));
    _ensurePolling();
    _processDownloadQueue();
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
    if (!await _checkDownloadFolder()) return;
    if (!await _checkAllSessionsBeforeDownload()) return;

    final s = settings ?? const DownloadSettings();
    final audioIds = <String>[];
    final dl = Map<String, DownloadStateData>.from(state.downloads);
    final seenIsrcs = <String>{}; // Dedup by ISRC within the batch

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

      // Dedup by ISRC within the same batch (bonus tracks from multiple editions)
      final isrc = (t['isrc'] ?? '').toString();
      if (isrc.isNotEmpty && !seenIsrcs.add(isrc)) {
        _log.i('[startAlbumDownload] skip ISRC duplicate in batch: $isrc');
        dl[baseId] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
        continue;
      }

      dl[baseId] = const DownloadStateData(state: DownloadState.queued, progress: 0.0);
      _downloadQueue.add(_QueuedTrack(t, tid, source, s, qualityOverride, batchKey));
    }

    if (audioIds.isEmpty) return;
    _batchTrackIds[batchKey] = audioIds;
    _batchData[batchKey] = _BatchData(tracks, s, source, qualityOverride);
    _ensurePolling();

    dl[batchKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
    emit(state.copyWith(downloads: dl));

    // Persist batch as in_progress so it survives restart
    final batchName = (tracks.isNotEmpty) ? (tracks.first['album_name'] as String? ?? '') : '';
    // Build parallel metadata list so _buildFromBatch() has track names
    final albumMeta = tracks.map((t) => <String, dynamic>{
      'name': (t['track_title'] ?? '') as String,
      'artist': (t['artist_name'] ?? '') as String,
      'cover': (t['cover_url'] ?? '') as String,
    }).toList();
    await _downloadCache.saveDownloadedBatch(
      batchKey, 'album', albumId, source, batchName,
      trackIds: audioIds,
      trackMeta: albumMeta,
    );

    _processDownloadQueue();
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
    final seenIsrcs = <String>{}; // Dedup by ISRC within the batch

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

      // Dedup by ISRC within the same batch (duplicate tracks across playlists)
      final isrc = (t['isrc'] ?? '').toString();
      if (isrc.isNotEmpty && !seenIsrcs.add(isrc)) {
        _log.i('[startPlaylistDownload] skip ISRC duplicate in batch: $isrc');
        dl[baseId] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
        continue;
      }

      _log.i('[startPlaylistDownload] ENQUEUE tid=$tid baseId=$baseId');
      dl[baseId] = const DownloadStateData(state: DownloadState.queued, progress: 0.0);
      _downloadQueue.add(_QueuedTrack(t, tid, source, s, qualityOverride, batchKey));
    }

    _log.i('[startPlaylistDownload] loop done: audioIds=${audioIds.length}');
    if (audioIds.isEmpty) { _log.w('[startPlaylistDownload] audioIds EMPTY'); return; }
    _batchTrackIds[batchKey] = audioIds;
    _batchData[batchKey] = _BatchData(tracks, s, source, qualityOverride);
    _log.i('[startPlaylistDownload] batch registered, _batchTrackIds.size=${_batchTrackIds.length}');
    _ensurePolling();

    dl[batchKey] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
    emit(state.copyWith(downloads: dl));

    // Persist batch as in_progress so it survives restart
    final batchName = (tracks.isNotEmpty) ? (tracks.first['album_name'] as String? ?? '') : '';
    final playlistMeta = tracks.map((t) => <String, dynamic>{
      'name': (t['track_title'] ?? '') as String,
      'artist': (t['artist_name'] ?? '') as String,
      'cover': (t['cover_url'] ?? '') as String,
    }).toList();
    await _downloadCache.saveDownloadedBatch(
      batchKey, 'playlist', playlistId, source, batchName,
      trackIds: audioIds,
      trackMeta: playlistMeta,
    );

    _processDownloadQueue();
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
    final stateKeys = <String>[];
    if (batch?.trackIds != null && batch!.trackIds!.isNotEmpty) {
      final decoded = jsonDecode(batch.trackIds!) as List<dynamic>;
      for (final entry in decoded) {
        if (entry is String) {
          stateKeys.add(entry);
        } else if (entry is Map<String, dynamic>) {
          final id = (entry['id'] ?? '') as String;
          if (id.isNotEmpty) stateKeys.add(id);
        }
      }
    }
    if (stateKeys.isNotEmpty) {
      // stateKeys are like "track_normalizedId_source"; extract normalized IDs
      // and also try original formats for robust DB deletion
      final allIds = <String>{};
      final fileStems = <String>{};
      final coversToDelete = <String>{};
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
              coversToDelete.add(meta.coverUrl!);
            }
          }
          // Clear the in-memory downloaded-track-ID cache so
          // startAlbumDownload no longer skips these tracks as
          // "already downloaded".
          _downloadedTrackIds.remove(extractedId);
        }
      }
      // Portadas: borrar cada URL una sola vez y solo si el álbum ya no está
      // likeado (el like muestra la misma portada en Mi Espacio).
      if (coversToDelete.isNotEmpty && !_isParentLiked(batchKey)) {
        for (final coverUrl in coversToDelete) {
          try { await _backend.deleteCover(coverUrl); } catch (_) {}
        }
      }
      await _downloadCache.deleteDownloadedTracks(allIds.toList());
      sl<PlayerCubit>().removeLocalFilesProviderIds(fileStems.toList(), deleteFiles: true);
    }
    await _downloadCache.removeDownloadedBatchByItem('album', albumId, effectiveSource);
    sl<LibraryCache>().invalidateAll();
    final dl = Map<String, DownloadStateData>.from(state.downloads);
    final fps = Set<String>.from(state.downloadedFingerprints);
    dl.remove(batchKey);
    // Remove individual track entries from state.downloads so completedTracks
    // no longer returns them in the "Canciones" tab of Mi Espacio.
    final trackerIds = <String>[];
    for (final stateKey in stateKeys) {
      dl.remove(stateKey);
      final meta = _trackMeta[stateKey];
      if (meta != null) {
        final fpName = meta.name.isNotEmpty ? meta.name : normalizeTrackId(meta.trackId);
        final fpArtist = meta.artist ?? '';
        fps.remove(fingerprintFromName(fpName, fpArtist));
      }
      _trackMeta.remove(stateKey);
      // Clear downloadedTrackIds so re-download is possible
      final parts = stateKey.split('_');
      if (parts.length >= 3) {
        final normId = parts.sublist(1, parts.length - 1).join('_');
        _downloadedTrackIds.remove(normId);
      }
      trackerIds.addAll(_itemIdToStateKey.entries
          .where((e) => e.value == stateKey)
          .map((e) => e.key));
      _itemIdToStateKey.removeWhere((k, v) => v == stateKey);
      dl.remove('${stateKey}_video');
      dl.remove('${stateKey}_lyrics');
      _itemIdToStateKey.removeWhere((k, v) =>
          v == '${stateKey}_video' || v == '${stateKey}_lyrics');
    }
    _pendingDeletes.addAll(trackerIds);
    for (final tid in trackerIds) {
      unawaited(_backend.cancelDownload(tid));
    }
    emit(state.copyWith(downloads: dl, downloadedFingerprints: fps));
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
    final stateKeys = <String>[];
    if (batch?.trackIds != null && batch!.trackIds!.isNotEmpty) {
      final decoded = jsonDecode(batch.trackIds!) as List<dynamic>;
      for (final entry in decoded) {
        if (entry is String) {
          stateKeys.add(entry);
        } else if (entry is Map<String, dynamic>) {
          final id = (entry['id'] ?? '') as String;
          if (id.isNotEmpty) stateKeys.add(id);
        }
      }
    }
    if (stateKeys.isNotEmpty) {
      final allIds = <String>{};
      final fileStems = <String>{};
      final coversToDelete = <String>{};
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
              coversToDelete.add(meta.coverUrl!);
            }
          }
          // Clear the in-memory downloaded-track-ID cache so
          // startPlaylistDownload no longer skips these tracks as
          // "already downloaded".
          _downloadedTrackIds.remove(extractedId);
        }
      }
      // Portadas: borrar cada URL una sola vez y solo si la playlist ya no
      // está likeada (el like muestra la misma portada en Mi Espacio).
      if (coversToDelete.isNotEmpty && !_isParentLiked(batchKey)) {
        for (final coverUrl in coversToDelete) {
          try { await _backend.deleteCover(coverUrl); } catch (_) {}
        }
      }
      await _downloadCache.deleteDownloadedTracks(allIds.toList());
      sl<PlayerCubit>().removeLocalFilesProviderIds(fileStems.toList(), deleteFiles: true);
    }
    await _downloadCache.removeDownloadedBatchByItem('playlist', playlistId, effectiveSource);
    sl<LibraryCache>().invalidateAll();
    final dl = Map<String, DownloadStateData>.from(state.downloads);
    final fps = Set<String>.from(state.downloadedFingerprints);
    dl.remove(batchKey);
    // Remove individual track entries from state.downloads so completedTracks
    // no longer returns them in the "Canciones" tab of Mi Espacio.
    final trackerIds = <String>[];
    for (final stateKey in stateKeys) {
      dl.remove(stateKey);
      final meta = _trackMeta[stateKey];
      if (meta != null) {
        final fpName = meta.name.isNotEmpty ? meta.name : normalizeTrackId(meta.trackId);
        final fpArtist = meta.artist ?? '';
        fps.remove(fingerprintFromName(fpName, fpArtist));
      }
      _trackMeta.remove(stateKey);
      final parts = stateKey.split('_');
      if (parts.length >= 3) {
        final normId = parts.sublist(1, parts.length - 1).join('_');
        _downloadedTrackIds.remove(normId);
      }
      trackerIds.addAll(_itemIdToStateKey.entries
          .where((e) => e.value == stateKey)
          .map((e) => e.key));
      _itemIdToStateKey.removeWhere((k, v) => v == stateKey);
      dl.remove('${stateKey}_video');
      dl.remove('${stateKey}_lyrics');
      _itemIdToStateKey.removeWhere((k, v) =>
          v == '${stateKey}_video' || v == '${stateKey}_lyrics');
    }
    _pendingDeletes.addAll(trackerIds);
    for (final tid in trackerIds) {
      unawaited(_backend.cancelDownload(tid));
    }
    emit(state.copyWith(downloads: dl, downloadedFingerprints: fps));
  }

  Future<void> _deleteBatch(String batchKey) async {
    final data = _batchData[batchKey];
    if (data == null) return;

    final allIdsToDelete = <String>{};
    final audioIdsInBatch = <String>[];
    final fileStems = <String>{};
    final coversToDelete = <String>{};
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
      // cover in coversDir – collect (deduped) track covers; the actual
      // deletion happens once per unique URL after the loop.
      final coverUrl = (t['cover_url'] as String?) ?? '';
      if (coverUrl.isNotEmpty) {
        final likeCubit = sl<LikeCubit>();
        final isLiked = [originalId, normalizedId]
            .any((id) => id.isNotEmpty && likeCubit.isItemIdLiked(id));
        if (!isLiked) coversToDelete.add(coverUrl);
      }
    }
    if (allIdsToDelete.isEmpty) return;

    // Portadas: borrar cada URL una sola vez y solo si el álbum/playlist padre
    // ya no está likeado (el like muestra la misma portada en Mi Espacio).
    if (coversToDelete.isNotEmpty && !_isParentLiked(batchKey)) {
      for (final coverUrl in coversToDelete) {
        try { await _backend.deleteCover(coverUrl); } catch (_) {}
      }
    }

    // Check reference counts BEFORE deleting: only remove files from disk
    // when no other batch (album/playlist) or like still references them.
    // Collect track IDs whose files are safe to delete from disk.
    final stemsToDelete = <String>{};
    final stemsToKeep = <String>{};
    for (final t in data.tracks) {
      final originalId = (t['track_id'] as String?) ?? '';
      if (originalId.isEmpty) continue;
      final normalizedId = normalizeTrackId(originalId);
      final likeCubit = sl<LikeCubit>();
      final isLiked = [originalId, normalizedId]
          .any((id) => id.isNotEmpty && likeCubit.isItemIdLiked(id));
      // batchCount includes this batch (not yet removed from DB), so >1 means shared
      final batchCount = await _downloadCache.countBatchesReferencingTrack(normalizedId);
      final safe = !isLiked && batchCount <= 1;
      if (safe) {
        stemsToDelete.addAll({originalId, normalizedId});
        for (final id in {originalId, normalizedId}) {
          if (id.isNotEmpty) stemsToDelete.add('lyrics_${_sha1Hex(id)}');
        }
        final title = (t['track_title'] as String?) ?? '';
        final artist = (t['artist_name'] as String?) ?? '';
        if (title.isNotEmpty && artist.isNotEmpty) {
          stemsToDelete.add('${_sanitizeFilename(artist)} - ${_sanitizeFilename(title)}');
        }
      } else {
        stemsToKeep.addAll({originalId, normalizedId});
      }
    }

    await _downloadCache.deleteDownloadedTracks(allIdsToDelete.toList());
    await _downloadCache.removeDownloadedBatches([batchKey]);

    // Remove file references from player cache for ALL tracks
    sl<PlayerCubit>().removeLocalFilesProviderIds(fileStems.toList(), deleteFiles: false);
    // Delete files only for tracks no other batch/like references
    if (stemsToDelete.isNotEmpty) {
      sl<PlayerCubit>().removeLocalFilesProviderIds(stemsToDelete.toList(), deleteFiles: true);
    }
    sl<LibraryCache>().invalidateAll();

    final dl = Map<String, DownloadStateData>.from(state.downloads);
    final fps = Set<String>.from(state.downloadedFingerprints);
    dl.remove(batchKey);
    final trackerIds = <String>[];
    for (final audioId in audioIdsInBatch) {
      dl.remove(audioId);
      // Remove fingerprint so _trackStateFor no longer reports "completed"
      final meta = _trackMeta[audioId];
      if (meta != null) {
        final fpName = meta.name.isNotEmpty ? meta.name : normalizeTrackId(meta.trackId);
        final fpArtist = meta.artist ?? '';
        fps.remove(fingerprintFromName(fpName, fpArtist));
      }
      _trackMeta.remove(audioId);
      // Clear the downloaded-track-ID cache so startAlbumDownload
      // no longer skips this track as "already downloaded".
      // audioId format: track_{normalizedId}_{source}
      final parts = audioId.split('_');
      if (parts.length >= 3) {
        final normId = parts.sublist(1, parts.length - 1).join('_');
        _downloadedTrackIds.remove(normId);
      }
      trackerIds.addAll(_itemIdToStateKey.entries
          .where((e) => e.value == audioId)
          .map((e) => e.key));
      _itemIdToStateKey.removeWhere((k, v) => v == audioId);
      // Limpiar state keys de video y letra
      dl.remove('${audioId}_video');
      dl.remove('${audioId}_lyrics');
      trackerIds.addAll(_itemIdToStateKey.entries
          .where((e) =>
              e.value == '${audioId}_video' || e.value == '${audioId}_lyrics')
          .map((e) => e.key));
      _itemIdToStateKey.removeWhere((k, v) =>
          v == '${audioId}_video' || v == '${audioId}_lyrics');
    }
    // Olvidar la persistencia y sacar la entrada del tracker de Go para que
    // el próximo poll no resucite la descarga borrada.
    _pendingDeletes.addAll(trackerIds);
    for (final tid in trackerIds) {
      unawaited(_backend.cancelDownload(tid));
    }
    _batchData.remove(batchKey);
    _batchTrackIds.remove(batchKey);
    _batchAutoRetryCount.remove(batchKey);
    _batchRetryFailed.remove(batchKey);
    emit(state.copyWith(downloads: dl, downloadedFingerprints: fps));
  }

  /// True when the album/playlist that owns [batchKey] is still liked. Its
  /// cover must NOT be deleted when removing the download, because Mi Espacio
  /// still displays that same cover for the liked item.
  bool _isParentLiked(String batchKey) {
    final parts = batchKey.split('_');
    if (parts.length < 3) return false;
    final type = parts.first;
    if (type != 'album' && type != 'playlist') return false;
    final parentId = parts.sublist(1, parts.length - 1).join('_');
    if (parentId.isEmpty) return false;
    final likeCubit = sl<LikeCubit>();
    return likeCubit.state.allLiked.values.any(
      (i) => i.type == type && normalizeTrackId(i.id) == parentId,
    );
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

    final dl = Map<String, DownloadStateData>.from(state.downloads);
    // Store ONLY by baseId — do NOT add audioKey to the downloads map
    // because the UI's prefix scan would match it as a separate entry,
    // showing multiple orange dots for the same track.
    dl[baseId] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
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
      null,
      (commonMeta['isrc'] as String?) ?? '',
    );
    _startedAt[baseId] = DateTime.now();
    _log.i('[dispatchSingleTrack] baseId=$baseId itemId="$itemId" title="${commonMeta['track_title']}" '
        'artist="${commonMeta['artist_name']}" isrc="${commonMeta['isrc']}" source="${commonMeta['source']}"');
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
      // Track video internally but do NOT add to downloads map —
      // the UI prefix scan would match it as a separate orange dot.
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
      // Track lyrics internally but do NOT add to downloads map.
      final lyricsStrategy = <String, dynamic>{
        ...commonMeta,
        'type': 'lyrics',
        'item_id': '${itemId}_lyrics',
        'source': settings.lyricsSource,
      };
      _itemIdToStateKey['${itemId}_lyrics'] = lyricsKey;
      backend.downloadByStrategy(jsonEncode(lyricsStrategy));
    }

    // Single emit after all RPC dispatches — avoids a race where _pollProgress
    // reads intermediate state between the old two-emit pattern.
    emit(state.copyWith(downloads: dl));
  }

  // ── Sequential download queue ──────────────────────────────

  /// Processes the global queue one track at a time. Batches are processed
  /// in FIFO order: all tracks from batch1 first, then batch2, etc.
  ///
  /// Guarantees:
  ///  • Only ONE track is dispatched at any time (strict FIFO).
  ///  • Before advancing to the next track the queue verifies the
  ///    previous download actually produced a playable file on disk.
  ///  • A failed/missing file marks the track as interrupted and
  ///    immediately advances (no infinite retry inside the queue).
  Future<void> _processDownloadQueue() async {
    if (_isProcessingQueue || _downloadQueue.isEmpty) return;
    _isProcessingQueue = true;

    while (_downloadQueue.isNotEmpty) {
      final track = _downloadQueue.removeAt(0);
      _currentTrackDone = Completer<void>();

      final normalizedId = normalizeTrackId(track.trackId);
      final baseId = 'track_${normalizedId}_${track.source}';
      _currentQueueTrackId = baseId;

      _log.i('[queue] ▶ START track=$baseId title="${track.trackMap['track_title']}" '  
          'queue_remaining=${_downloadQueue.length}');

      final dl = Map<String, DownloadStateData>.from(state.downloads);
      dl[baseId] = const DownloadStateData(state: DownloadState.inProgress, progress: 0.0);
      // Mark the batch this track belongs to as inProgress
      final bk = track.batchKey;
      if (bk != null) {
        dl[bk] = const DownloadStateData(
          state: DownloadState.inProgress,
          progress: 0.0,
        );
      }
      emit(state.copyWith(downloads: dl));

      _dispatchBatchTrack(track.trackMap, track.trackId, track.source, track.settings,
          qualityOverride: track.qualityOverride);

      try {
        await _currentTrackDone!.future.timeout(const Duration(seconds: 90));
      } catch (_) {
        _log.w('[queue] ⏰ TIMEOUT for $baseId after 90s — moving to next track');
        // Do NOT cancel the Go tracker — the download may still be running.
        // The poll will detect completion later and mark it as completed.
        // Move to the next track so the queue isn't blocked.
      }

      // Yield to let _pollProgress's emit propagate the state update
      // (completed/interrupted) before we read it below.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // ── If still inProgress after signal, check file on disk directly ──
      // Go's finalize may fire _signalTrackDone before the Dart poll processes
      // the completion. Look for the file immediately to avoid the orange dot.
      if (state.downloads[baseId]?.state == DownloadState.inProgress) {
        final altFile = await _findAlternativePlayableFile(baseId, '');
        if (altFile != null && altFile.isNotEmpty) {
          _log.i('[queue] $baseId: file found on disk after signal: $altFile — marking completed');
          final tdl = Map<String, DownloadStateData>.from(state.downloads);
          tdl[baseId] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
          emit(state.copyWith(downloads: tdl));
        }
      }

      // ── Verify the download actually produced a file ──
      final currentDl = state.downloads[baseId]?.state;
      if (currentDl == DownloadState.completed) {
        var fileOk = await _verifyDownloadedFile(baseId);
        if (fileOk) {
          _redownloadQueue.remove(baseId);
        } else {
          // Wait briefly for other providers (Apple Music .m4a) to finalize.
          for (var attempt = 1; attempt <= 3 && !fileOk; attempt++) {
            _log.i('[queue] $baseId: verify attempt $attempt — waiting 3s...');
            await Future<void>.delayed(const Duration(seconds: 3));
            final recheckDl = state.downloads[baseId]?.state;
            if (recheckDl == DownloadState.completed) {
              fileOk = await _verifyDownloadedFile(baseId);
            }
          }
          if (!fileOk) {
            // Do NOT re-dispatch here — it would break FIFO by starting a
            // concurrent download. Just mark interrupted; the batch auto-retry
            // mechanism will pick this up after the album finishes.
            _log.w('[queue] ⚠ file missing/corrupt for $baseId — marking interrupted');
            final tdl = Map<String, DownloadStateData>.from(state.downloads);
            tdl[baseId] = const DownloadStateData(state: DownloadState.interrupted, progress: 0.0);
            emit(state.copyWith(downloads: tdl));
          }
        }
      } else if (currentDl == DownloadState.inProgress) {
        // Track still in-progress (Go didn't report done yet, e.g. timeout).
        // Give it one more chance — the poll may have just persisted the file.
        await Future<void>.delayed(const Duration(seconds: 3));
        final finalCheck = state.downloads[baseId]?.state;
        if (finalCheck == DownloadState.completed) {
          final fileOk = await _verifyDownloadedFile(baseId);
          if (fileOk) _redownloadQueue.remove(baseId);
        }
      }

      _log.i('[queue] ✔ DONE track=$baseId result=${state.downloads[baseId]?.state}');
    }

    _currentQueueTrackId = null;
    _isProcessingQueue = false;
    _log.i('[queue] ═══ QUEUE EMPTY ═══');
  }

  /// Verifies that a completed track actually has a playable file on disk.
  /// Returns false if the file is missing, too small, or doesn't start
  /// with valid audio magic bytes. Also searches for alternative playable
  /// files when the stored path is broken (e.g. after provider race).
  Future<bool> _verifyDownloadedFile(String baseId) async {
    final meta = _trackMeta[baseId];
    if (meta == null) return false;
    final filePath = await _downloadCache.getFilePathById(meta.trackId);
    if (filePath == null || filePath.isEmpty) {
      // Try the normalized ID as fallback
      final altPath = await _downloadCache.getFilePathById(baseId);
      if (altPath != null && altPath.isNotEmpty) {
        if (await _isDecodableAudioFile(File(altPath))) return true;
        // File from DB is not playable — search for an alternative on disk
        final diskAlt = await _findAlternativePlayableFile(baseId, altPath);
        if (diskAlt != null) {
          _log.i('[verify] alternative found for $baseId: $diskAlt');
          try {
            final nid = meta.trackId.isNotEmpty ? meta.trackId : baseId;
            await _downloadCache.saveDownloadedTrack(
              id: nid, trackName: meta.name, artistName: meta.artist ?? '',
              filePath: diskAlt, service: meta.source,
            );
          } catch (_) {}
          return true;
        }
      }
      // DB has no row for this track — search disk directly for a playable
      // file (Apple Music .m4a or SoundCloud .mp3 may exist even though
      // the DB was never updated by the poll's failed→persist path).
      final diskAlt = await _findAlternativePlayableFile(baseId);
      if (diskAlt != null) {
        _log.i('[verify] no DB row but found on disk: $diskAlt for $baseId');
        try {
          final nid = meta.trackId.isNotEmpty ? meta.trackId : baseId;
          await _downloadCache.saveDownloadedTrack(
            id: nid, trackName: meta.name, artistName: meta.artist ?? '',
            filePath: diskAlt, service: meta.source,
          );
        } catch (_) {}
        return true;
      }
      return false;
    }
    if (await _isDecodableAudioFile(File(filePath))) return true;
    // Stored file exists but is not playable — search for alternative
    final diskAlt = await _findAlternativePlayableFile(baseId, filePath);
    if (diskAlt != null) {
      _log.i('[verify] alternative found for $baseId: $diskAlt');
      try {
        final nid = meta.trackId.isNotEmpty ? meta.trackId : baseId;
        await _downloadCache.updateFilePath(nid, diskAlt);
      } catch (_) {}
      return true;
    }
    return false;
  }

  /// Cancels a tracker entry that belongs to [stateKey] so Go stops
  /// reporting it. Prevents ghost resurrection on the next poll cycle.
  void _cancelOrphanedTracker(String stateKey) {
    final trackerIds = _itemIdToStateKey.entries
        .where((e) => e.value == stateKey)
        .map((e) => e.key)
        .toList();
    _pendingDeletes.addAll(trackerIds);
    for (final tid in trackerIds) {
      unawaited(_backend.cancelDownload(tid));
    }
  }

  /// Signals the queue that the current track has finished.
  void _signalTrackDone(String stateKey) {
    if (_currentTrackDone != null && !_currentTrackDone!.isCompleted && stateKey == _currentQueueTrackId) {
      _currentTrackDone!.complete();
    }
  }

  /// Enqueues a single track. Uses the global queue so it respects batch order.
  void enqueueSingleTrack({
    required Map<String, dynamic> commonMeta,
    required DownloadSettings settings,
    required String baseId,
    String? qualityOverride,
  }) {
    final itemId = commonMeta['item_id'] as String? ?? commonMeta['track_id'] as String? ?? '';
    final source = commonMeta['source'] as String? ?? '';

    final dl = Map<String, DownloadStateData>.from(state.downloads);
    dl[baseId] = const DownloadStateData(state: DownloadState.queued, progress: 0.0);
    emit(state.copyWith(downloads: dl));

    _downloadQueue.add(_QueuedTrack(commonMeta, itemId, source, settings, qualityOverride, '_singles'));
    _processDownloadQueue();
  }

  /// Returns the local file path for a downloaded track, or null if not found.
  Future<String?> getTrackFilePath(String trackId, String source) async {
    final normalizedId = normalizeTrackId(trackId);
    final audioId = 'track_${normalizedId}_$source';
    final meta = _trackMeta[audioId];
    final idsToTry = <String>{};
    if (meta != null && meta.trackId.isNotEmpty) idsToTry.add(meta.trackId);
    idsToTry.add(normalizedId);
    if (trackId.isNotEmpty) idsToTry.add(trackId);
    for (final id in idsToTry) {
      final path = await _downloadCache.getFilePathById(id);
      if (path != null && path.isNotEmpty) return path;
    }
    return null;
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
    // Check if ANY other batch (album/playlist) or liked item still references this track.
    // If so, only remove the DB row — keep the file on disk for the other consumer.
    bool otherConsumerExists = false;
    for (final id in idsToTry) {
      if (id.isEmpty) continue;
      final batchCount = await _downloadCache.countBatchesReferencingTrack(id);
      if (batchCount > 1) { otherConsumerExists = true; break; }
    }
    // Also check if the track is liked — likes keep their own copy.
    final likeCubit = sl<LikeCubit>();
    final isLiked = [meta?.trackId ?? '', trackId, normalizedId]
        .any((id) => id.isNotEmpty && likeCubit.isItemIdLiked(id));
    if (isLiked) otherConsumerExists = true;

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
    // Only delete files from disk when NO other playlist/album/like references them.
    sl<PlayerCubit>().removeLocalFilesProviderIds(fileStems.toList(), deleteFiles: !otherConsumerExists);
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

    // Limpiar mapeo de item IDs del backend y olvidar la persistencia para que
    // re-descargar el mismo track vuelva a guardarlo. Además pedirle a Go que
    // deje de reportar la entrada: si no, el próximo poll la volvería a guardar
    // (resurrección fantasma de la descarga borrada).
    final trackerIds = _itemIdToStateKey.entries
        .where((e) =>
            e.value == audioId || e.value == videoKey || e.value == lyricsKey)
        .map((e) => e.key)
        .toList();
    _itemIdToStateKey.removeWhere((k, v) => trackerIds.contains(k));
    // Keep in _completedPersisted to block resurrection; add to _pendingDeletes
    // so the poll skips these IDs even after _completedPersisted is cleaned up
    // for re-download purposes. The poll will clean _pendingDeletes once the
    // Go tracker entry disappears (confirming the cancel took effect).
    _pendingDeletes.addAll(trackerIds);
    for (final tid in trackerIds) {
      unawaited(_backend.cancelDownload(tid));
    }

    // Limpiar fingerprints para que no reaparezca
    if (meta != null) {
      final fpName = meta.name.isNotEmpty ? meta.name : normalizedId;
      final fpArtist = meta.artist ?? '';
      fps.remove(fingerprintFromName(fpName, fpArtist));
    }

    // If this track belongs to a batch, update the batch state accordingly.
    // The audioId in _batchTrackIds may use a different source than `source`
    // (e.g., batch used "spotify-web" but track shows "apple-music" from poll).
    // Match by normalized ID to handle source mismatches.
    for (final batchKey in _batchTrackIds.keys.toList()) {
      final trackIds = _batchTrackIds[batchKey]!;
      // Find the audioId in this batch that matches the normalized ID
      String? matchedAudioId;
      for (final tid in trackIds) {
        // audioId format: track_{normalizedId}_{source}
        final tidParts = tid.split('_');
        if (tidParts.length >= 3) {
          final tidNormId = tidParts.sublist(1, tidParts.length - 1).join('_');
          if (tidNormId == normalizedId) {
            matchedAudioId = tid;
            break;
          }
        }
      }
      if (matchedAudioId != null) {
        trackIds.remove(matchedAudioId);
        // Also remove from _batchData.tracks to keep batch metadata consistent
        final batchData = _batchData[batchKey];
        if (batchData != null) {
          batchData.tracks.removeWhere((t) {
            final tNormId = normalizeTrackId((t['track_id'] as String?) ?? '');
            return tNormId == normalizedId;
          });
        }
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
          if (allDone && completed == total) {
            dl[batchKey] = const DownloadStateData(state: DownloadState.completed, progress: 1.0);
            await _finalizeCompletedBatch(batchKey, trackIds);
            _batchTrackIds.remove(batchKey);
          } else {
            dl[batchKey] = DownloadStateData(
              state: allDone ? DownloadState.none : (completed > 0 ? DownloadState.inProgress : DownloadState.none),
              progress: total > 0 ? completed / total : 0.0,
            );
          }
        } else {
          dl.remove(batchKey);
          _batchTrackIds.remove(batchKey);
          _batchData.remove(batchKey);
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
        // Prefer local coverPath (JPG saved to disk) over network URL
        final cover = (meta.coverPath != null && meta.coverPath!.isNotEmpty)
            ? meta.coverPath
            : meta.coverUrl;
        result.add(FeedItem(
          id: meta.trackId,
          type: 'track', name: meta.name,
          artists: meta.artist, coverUrl: cover,
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
      null,
      (trackMap['isrc'] as String?) ?? '',
    );
    dispatchDownloads(cubit: this, commonMeta: commonMeta, settings: settings, baseId: baseId, qualityOverride: qualityOverride, isBatchDispatch: true);
  }
}
