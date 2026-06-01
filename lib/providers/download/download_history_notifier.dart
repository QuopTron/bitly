part of 'package:bitly/providers/download/download_queue_provider.dart';
class DownloadQueueLookup {
  final Map<String, DownloadItem> byTrackId;
  final Map<String, DownloadItem> byItemId;
  final Map<String, int> indexByItemId;
  final Map<String, DownloadItem> byNormalizedName;
  final List<String> itemIds;
  final int queuedCount;
  final int completedCount;
  final int failedCount;
  final int activeDownloadsCount;

  const DownloadQueueLookup.empty()
    : byTrackId = const {},
      byItemId = const {},
      indexByItemId = const {},
      byNormalizedName = const {},
      itemIds = const [],
      queuedCount = 0,
      completedCount = 0,
      failedCount = 0,
      activeDownloadsCount = 0;

  DownloadQueueLookup._({
    required Map<String, DownloadItem> byTrackId,
    required Map<String, DownloadItem> byItemId,
    required Map<String, int> indexByItemId,
    required Map<String, DownloadItem> byNormalizedName,
    required List<String> itemIds,
    required this.queuedCount,
    required this.completedCount,
    required this.failedCount,
    required this.activeDownloadsCount,
  }) : byTrackId = Map.unmodifiable(byTrackId),
       byItemId = Map.unmodifiable(byItemId),
       indexByItemId = Map.unmodifiable(indexByItemId),
       byNormalizedName = Map.unmodifiable(byNormalizedName),
       itemIds = List.unmodifiable(itemIds);

  factory DownloadQueueLookup.fromItems(List<DownloadItem> items) {
    final byTrackId = <String, DownloadItem>{};
    final byItemId = <String, DownloadItem>{};
    final indexByItemId = <String, int>{};
    final byNormalizedName = <String, DownloadItem>{};
    final itemIds = <String>[];
    var queuedCount = 0;
    var completedCount = 0;
    var failedCount = 0;
    var activeDownloadsCount = 0;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      byTrackId.putIfAbsent(item.track.id, () => item);
      byItemId[item.id] = item;
      indexByItemId[item.id] = index;
      itemIds.add(item.id);
      final nKey = '${normalizeForMatch(item.track.name)}|${normalizeForMatch(item.track.artistName)}';
      if (nKey != '|') byNormalizedName.putIfAbsent(nKey, () => item);
      if (_countsAsQueued(item.status)) queuedCount++;
      if (item.status == DownloadStatus.completed) completedCount++;
      if (item.status == DownloadStatus.failed) failedCount++;
      if (item.status == DownloadStatus.downloading) activeDownloadsCount++;
    }
    return DownloadQueueLookup._(
      byTrackId: byTrackId,
      byItemId: byItemId,
      indexByItemId: indexByItemId,
      byNormalizedName: byNormalizedName,
      itemIds: itemIds,
      queuedCount: queuedCount,
      completedCount: completedCount,
      failedCount: failedCount,
      activeDownloadsCount: activeDownloadsCount,
    );
  }

  static bool _countsAsQueued(DownloadStatus status) =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.finalizing;

  static int _deltaForStatus({
    required DownloadStatus previous,
    required DownloadStatus next,
    required bool Function(DownloadStatus status) predicate,
  }) {
    final had = predicate(previous);
    final has = predicate(next);
    if (had == has) return 0;
    return has ? 1 : -1;
  }

  DownloadQueueLookup updatedForIndices({
    required List<DownloadItem> previousItems,
    required List<DownloadItem> nextItems,
    required Iterable<int> changedIndices,
  }) {
    if (previousItems.length != nextItems.length ||
        itemIds.length != nextItems.length ||
        indexByItemId.length != nextItems.length) {
      return DownloadQueueLookup.fromItems(nextItems);
    }

    final normalizedChanged = <int>[];
    for (final index in changedIndices) {
      if (index < 0 || index >= nextItems.length) {
        return DownloadQueueLookup.fromItems(nextItems);
      }
      normalizedChanged.add(index);
    }
    if (normalizedChanged.isEmpty) return this;

    var nextQueuedCount = queuedCount;
    var nextCompletedCount = completedCount;
    var nextFailedCount = failedCount;
    var nextActiveDownloadsCount = activeDownloadsCount;
    Map<String, DownloadItem>? nextByItemId;
    Map<String, DownloadItem>? nextByTrackId;
    Map<String, DownloadItem>? nextByNormalizedName;

    for (final index in normalizedChanged) {
      final previous = previousItems[index];
      final next = nextItems[index];
      if (previous.id != next.id || previous.track.id != next.track.id) {
        return DownloadQueueLookup.fromItems(nextItems);
      }

      nextByItemId ??= Map<String, DownloadItem>.from(byItemId);
      nextByItemId[next.id] = next;
      if (byTrackId[next.track.id]?.id == previous.id) {
        nextByTrackId ??= Map<String, DownloadItem>.from(byTrackId);
        nextByTrackId[next.track.id] = next;
      }
      final oldNKey = '${normalizeForMatch(previous.track.name)}|${normalizeForMatch(previous.track.artistName)}';
      final newNKey = '${normalizeForMatch(next.track.name)}|${normalizeForMatch(next.track.artistName)}';
      if (oldNKey != '|' || newNKey != '|') {
        nextByNormalizedName ??= Map<String, DownloadItem>.from(byNormalizedName);
      }
      if (oldNKey != '|' && nextByNormalizedName?[oldNKey]?.id == previous.id) {
        nextByNormalizedName?.remove(oldNKey);
      }
      if (newNKey != '|') {
        nextByNormalizedName?.putIfAbsent(newNKey, () => next);
      }
      nextQueuedCount += _deltaForStatus(
        previous: previous.status,
        next: next.status,
        predicate: _countsAsQueued,
      );
      nextCompletedCount += _deltaForStatus(
        previous: previous.status,
        next: next.status,
        predicate: (status) => status == DownloadStatus.completed,
      );
      nextFailedCount += _deltaForStatus(
        previous: previous.status,
        next: next.status,
        predicate: (status) => status == DownloadStatus.failed,
      );
      nextActiveDownloadsCount += _deltaForStatus(
        previous: previous.status,
        next: next.status,
        predicate: (status) => status == DownloadStatus.downloading,
      );
    }

    return DownloadQueueLookup._(
      byTrackId: nextByTrackId ?? byTrackId,
      byItemId: nextByItemId ?? byItemId,
      byNormalizedName: nextByNormalizedName ?? byNormalizedName,
      indexByItemId: indexByItemId,
      itemIds: itemIds,
      queuedCount: nextQueuedCount,
      completedCount: nextCompletedCount,
      failedCount: nextFailedCount,
      activeDownloadsCount: nextActiveDownloadsCount,
    );
  }
}


class _NativeWorkerStartupTimeout implements Exception {
  @override
  String toString() => 'Native worker did not publish run snapshot';
}

final downloadQueueLookupProvider = Provider<DownloadQueueLookup>((ref) {
  return ref.watch(downloadQueueProvider.select((s) => s.lookup));
});

class _AlbumRgTrackEntry {
  String filePath;
  final String trackId;
  final double integratedLufs;
  final double truePeakLinear;
  final double durationSecs;

  _AlbumRgTrackEntry({
    required this.filePath,
    required this.trackId,
    required this.integratedLufs,
    required this.truePeakLinear,
    required this.durationSecs,
  });
}

class _AlbumRgAccumulator {
  final List<_AlbumRgTrackEntry> entries = [];
}

class _DeezerLookupPreparation {
  final Track track;
  final String? deezerTrackId;

  const _DeezerLookupPreparation({required this.track, this.deezerTrackId});
}

class _DeezerExtendedMetadataFields {
  final String? genre;
  final String? label;
  final String? copyright;

  const _DeezerExtendedMetadataFields({this.genre, this.label, this.copyright});

  bool get hasAnyValue =>
      (genre != null && genre!.isNotEmpty) ||
      (label != null && label!.isNotEmpty) ||
      (copyright != null && copyright!.isNotEmpty);
}
class DownloadHistoryNotifier extends Notifier<DownloadHistoryState> {
  static const int _initialHistoryLoadLimit = 100;
  static const int _safRepairBatchSize = 20;
  static const int _safRepairMaxPerLaunch = 60;
  static const int _orphanCleanupMaxPerLaunch = 80;
  static const int _audioMetadataBackfillMaxPerLaunch = 24;
  static const _startupMaintenanceDelay = Duration(seconds: 4);
  static const _startupMaintenanceStepGap = Duration(milliseconds: 250);
  static const _startupSafRepairCursorKey =
      'history_startup_saf_repair_cursor_v1';
  static const _startupOrphanCursorKey = 'history_startup_orphan_cursor_v1';
  static const _startupAudioCursorKey = 'history_startup_audio_cursor_v1';
  final HistoryDatabase _db = HistoryDatabase.instance;
  bool _isLoaded = false;
  bool _isSafRepairInProgress = false;
  bool _isAudioMetadataBackfillInProgress = false;
  bool _startupMaintenanceScheduled = false;

  @override
  DownloadHistoryState build() {
    _loadFromDatabaseSync();
    return DownloadHistoryState();
  }

  void _loadFromDatabaseSync() {
    if (_isLoaded) return;
    _isLoaded = true;
    Future.microtask(() async {
      await _loadFromDatabase();
    });
  }

  Future<void> _loadFromDatabase() async {
    try {
      final countFuture = _db.getCount();
      final jsonList = await _db.getAll(limit: _initialHistoryLoadLimit);
      final rawItems = jsonList
          .map((e) => DownloadHistoryItem.fromJson(e))
          .toList();
      final totalCount = await countFuture;

      // Deduplicate by ISRC > name|artist to avoid
      // multiple cards for the same song from different sources
      final items = _deduplicateHistoryItems(rawItems);

      if (items.length < rawItems.length) {
        _historyLog.i(
          'Deduplicated history: ${rawItems.length} → ${items.length} unique items',
        );
        // Clean up duplicates from database
        await _deleteDuplicatesFromDb(rawItems, items);
      }

      state = state.copyWith(
        items: items,
        totalCount: totalCount,
        loadedIndexVersion: state.loadedIndexVersion + 1,
        lookupItems: items,
      );
      _historyLog.i(
        'Loaded ${items.length}/$totalCount recent history items from SQLite database',
      );
      _scheduleStartupMaintenance(items);
    } catch (e, stack) {
      _historyLog.e('Failed to load history from database: $e', e, stack);
    }
  }

  List<DownloadHistoryItem> _deduplicateHistoryItems(
    List<DownloadHistoryItem> items,
  ) {
    if (items.length < 2) return items;

    final byIsrc = <String, DownloadHistoryItem>{};
    final byNameArtist = <String, DownloadHistoryItem>{};
    final result = <DownloadHistoryItem>[];

    for (final item in items) {
      final isrc = HistoryDatabase.normalizeIsrc(item.isrc);
      if (isrc.isNotEmpty) {
        final existing = byIsrc[isrc];
        if (existing != null) {
          // Keep the one with higher quality info or more recent
          final keep = _pickBetterHistoryItem(existing, item);
          byIsrc[isrc] = keep;
        } else {
          byIsrc[isrc] = item;
        }
        continue;
      }

      final key = HistoryDatabase.matchKeyFor(item.trackName, item.artistName);
      if (key.isNotEmpty) {
        final existing = byNameArtist[key];
        if (existing != null) {
          final keep = _pickBetterHistoryItem(existing, item);
          byNameArtist[key] = keep;
        } else {
          byNameArtist[key] = item;
        }
        continue;
      }

      result.add(item);
    }

    result.addAll(byIsrc.values);
    result.addAll(byNameArtist.values);
    return result;
  }

  DownloadHistoryItem _pickBetterHistoryItem(
    DownloadHistoryItem a,
    DownloadHistoryItem b,
   ) {
     // Prefer the one with a real file path
     if (a.filePath.isEmpty && b.filePath.isNotEmpty) return b;
     if (b.filePath.isEmpty && a.filePath.isNotEmpty) return a;
     // Prefer higher quality
     if (a.quality == null && b.quality != null) return b;
     if (b.quality == null && a.quality != null) return a;
     // Prefer the most recent (handle null)
     if (a.downloadedAt == null && b.downloadedAt == null) return a;
     if (a.downloadedAt == null) return b;
     if (b.downloadedAt == null) return a;
     if (a.downloadedAt!.isBefore(b.downloadedAt!)) return b;
     return a;
   }

  Future<void> _deleteDuplicatesFromDb(
    List<DownloadHistoryItem> all,
    List<DownloadHistoryItem> keep,
  ) async {
    final keepIds = keep.map((e) => e.id).toSet();
    final deleteIds = all
        .where((e) => !keepIds.contains(e.id))
        .map((e) => e.id)
        .toList(growable: false);
    if (deleteIds.isNotEmpty) {
      await _db.deleteByIds(deleteIds);
    }
  }

  void _scheduleStartupMaintenance(List<DownloadHistoryItem> initialItems) {

    if (_startupMaintenanceScheduled) {
      return;
    }
    _startupMaintenanceScheduled = true;

    unawaited(
      Future<void>.delayed(_startupMaintenanceDelay, () async {
        try {
          final prefs = await SharedPreferences.getInstance();

          if (Platform.isAndroid) {
            await _repairMissingSafEntries(
              initialItems,
              maxItems: _safRepairMaxPerLaunch,
              prefs: prefs,
            );
            await Future<void>.delayed(_startupMaintenanceStepGap);
          }

          await _cleanupOrphanedDownloadsIncremental(
            maxItems: _orphanCleanupMaxPerLaunch,
            prefs: prefs,
          );
          await Future<void>.delayed(_startupMaintenanceStepGap);

          final currentItems = state.items;
          if (currentItems.isNotEmpty) {
            await _backfillAudioMetadata(
              currentItems,
              maxItems: _audioMetadataBackfillMaxPerLaunch,
              prefs: prefs,
            );
          }
        } catch (e, stack) {
          _historyLog.w('Startup history maintenance failed: $e');
          _historyLog.d('$stack');
        }
      }),
    );
  }

  int _readStartupCursor(SharedPreferences prefs, String key, int totalCount) {
    if (totalCount <= 0) {
      return 0;
    }
    final cursor = prefs.getInt(key) ?? 0;
    if (cursor < 0 || cursor >= totalCount) {
      return 0;
    }
    return cursor;
  }

  Future<void> _writeStartupCursor(
    SharedPreferences prefs,
    String key,
    int nextCursor,
    int totalCount,
  ) async {
    if (totalCount <= 0 || nextCursor <= 0 || nextCursor >= totalCount) {
      await prefs.remove(key);
      return;
    }
    await prefs.setInt(key, nextCursor);
  }

  String _fileNameFromUri(String uri) {
    try {
      final parsed = Uri.parse(uri);
      if (parsed.pathSegments.isNotEmpty) {
        return Uri.decodeComponent(parsed.pathSegments.last);
      }
    } catch (e) {}
    return '';
  }

  Future<void> _repairMissingSafEntries(
    List<DownloadHistoryItem> items, {
    required int maxItems,
    required SharedPreferences prefs,
  }) async {
    if (_isSafRepairInProgress || items.isEmpty) {
      return;
    }
    _isSafRepairInProgress = true;

    final candidateIndexes = <int>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.storageMode != 'saf') continue;
      if (item.safRepaired) continue;
      if (item.downloadTreeUri == null || item.downloadTreeUri!.isEmpty) {
        continue;
      }
      final hasFilePath = item.filePath.trim().isNotEmpty;
      final hasSafFileName =
          item.safFileName != null && item.safFileName!.trim().isNotEmpty;
      if (!hasFilePath && !hasSafFileName) {
        continue;
      }
      candidateIndexes.add(i);
    }

    if (candidateIndexes.isEmpty) {
      await prefs.remove(_startupSafRepairCursorKey);
      _isSafRepairInProgress = false;
      return;
    }

    final startCursor = _readStartupCursor(
      prefs,
      _startupSafRepairCursorKey,
      candidateIndexes.length,
    );
    final endCursor = (startCursor + maxItems).clamp(
      0,
      candidateIndexes.length,
    );
    final selectedIndexes = candidateIndexes.sublist(startCursor, endCursor);

    if (selectedIndexes.isEmpty) {
      await prefs.remove(_startupSafRepairCursorKey);
      _isSafRepairInProgress = false;
      return;
    }

    final updatedItems = [...items];
    final persistedUpdates = <Map<String, dynamic>>[];
    var changed = false;
    var repairedCount = 0;
    var verifiedCount = 0;

    try {
      for (var c = 0; c < selectedIndexes.length; c++) {
        final i = selectedIndexes[c];
        final item = items[i];
        final rawPath = item.filePath.trim();
        final isDirectSafUri = rawPath.isNotEmpty && isContentUri(rawPath);

        if (isDirectSafUri) {
          final exists = await fileExists(rawPath);
          if (exists) {
            final verified = item.copyWith(
              safRepaired: true,
              safFileName: item.safFileName ?? _fileNameFromUri(rawPath),
            );
            updatedItems[i] = verified;
            changed = true;
            verifiedCount++;
            persistedUpdates.add(verified.toJson());
            continue;
          }
        }

        var fallbackName = (item.safFileName ?? '').trim();
        if (fallbackName.isEmpty && isDirectSafUri) {
          fallbackName = _fileNameFromUri(rawPath);
        }
        if (fallbackName.isEmpty) {
          _historyLog.w('Missing SAF filename for history item: ${item.id}');
          continue;
        }

        try {
          if (item.downloadTreeUri == null || item.downloadTreeUri!.isEmpty) {
            _historyLog.w('Missing downloadTreeUri for item: ${item.id}');
            continue;
          }

          final resolved = await PlatformBridge.resolveSafFile(
            treeUri: item.downloadTreeUri!,
            relativeDir: item.safRelativeDir ?? '',
            fileName: fallbackName,
          ).timeout(const Duration(seconds: 10));
          final newUri = (resolved['uri'] as String? ?? '').trim();
          if (newUri.isEmpty) continue;

          final newRelativeDir = resolved['relative_dir'] as String?;
          final updated = item.copyWith(
            filePath: newUri,
            safRelativeDir:
                (newRelativeDir != null && newRelativeDir.isNotEmpty)
                ? newRelativeDir
                : item.safRelativeDir,
            safFileName: fallbackName,
            safRepaired: true,
          );

          updatedItems[i] = updated;
          changed = true;
          repairedCount++;
          persistedUpdates.add(updated.toJson());
        } catch (e) {
          _historyLog.w('Failed to repair SAF URI: $e');
        }

        if ((c + 1) % _safRepairBatchSize == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
      }

      if (changed) {
        await _db.upsertBatch(persistedUpdates);
        state = state.copyWith(
          items: updatedItems,
          loadedIndexVersion: state.loadedIndexVersion + 1,
          lookupItems: _lookupItemsWithUpdates(updatedItems),
        );
        _historyLog.i(
          'SAF repair pass: verified=$verifiedCount, repaired=$repairedCount, checked=${selectedIndexes.length}',
        );
      }
      await _writeStartupCursor(
        prefs,
        _startupSafRepairCursorKey,
        endCursor,
        candidateIndexes.length,
      );
    } finally {
      _isSafRepairInProgress = false;
    }
  }

  int? _readPositiveInt(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final asInt = value.toInt();
      return asInt > 0 ? asInt : null;
    }
    final parsed = int.tryParse(value.toString());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  bool _supportsAudioMetadataProbe(String filePath) {
    final trimmed = filePath.trim().toLowerCase();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('content://')) return true;
    return trimmed.endsWith('.flac') ||
        trimmed.endsWith('.m4a') ||
        trimmed.endsWith('.mp4') ||
        trimmed.endsWith('.aac') ||
        trimmed.endsWith('.mp3') ||
        trimmed.endsWith('.opus') ||
        trimmed.endsWith('.ogg');
  }

  bool _shouldBackfillAudioMetadata(DownloadHistoryItem item) {
    if (!_supportsAudioMetadataProbe(item.filePath)) {
      return false;
    }

    final trimmedPath = item.filePath.trim().toLowerCase();
    final hasResolvedSpecs =
        item.bitDepth != null &&
        item.bitDepth! > 0 &&
        item.sampleRate != null &&
        item.sampleRate! > 0;
    final needsLosslessSpecProbe =
        !hasResolvedSpecs &&
        (trimmedPath.endsWith('.flac') ||
            trimmedPath.endsWith('.m4a') ||
            trimmedPath.endsWith('.mp4') ||
            trimmedPath.endsWith('.aac') ||
            trimmedPath.startsWith('content://'));

    final needsFormatBackfill = item.format == null;
    if (hasResolvedSpecs && !isPlaceholderQualityLabel(item.quality)) {
      final needsComposerBackfill =
          normalizeOptionalString(item.composer) == null;
      final needsDurationBackfill = item.duration == null || item.duration == 0;
      final needsTrackNumberBackfill = item.trackNumber == null;
      final needsTotalTracksBackfill = item.totalTracks == null;
      final needsDiscNumberBackfill = item.discNumber == null;
      final needsTotalDiscsBackfill = item.totalDiscs == null;
      return needsFormatBackfill ||
          needsComposerBackfill ||
          needsDurationBackfill ||
          needsTrackNumberBackfill ||
          needsTotalTracksBackfill ||
          needsDiscNumberBackfill ||
          needsTotalDiscsBackfill;
    }

    final needsComposerBackfill =
        normalizeOptionalString(item.composer) == null;
    final needsDurationBackfill = item.duration == null || item.duration == 0;
    final needsTrackNumberBackfill = item.trackNumber == null;
    final needsTotalTracksBackfill = item.totalTracks == null;
    final needsDiscNumberBackfill = item.discNumber == null;
    final needsTotalDiscsBackfill = item.totalDiscs == null;
    return needsLosslessSpecProbe ||
        isPlaceholderQualityLabel(item.quality) ||
        normalizeOptionalString(item.quality) == null ||
        needsFormatBackfill ||
        needsComposerBackfill ||
        needsDurationBackfill ||
        needsTrackNumberBackfill ||
        needsTotalTracksBackfill ||
        needsDiscNumberBackfill ||
        needsTotalDiscsBackfill;
  }

  String? _normalizeAudioFormatValue(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == 'flac') return 'FLAC';
    if (s == 'opus' || s == 'ogg') return 'OPUS';
    if (s == 'mp3') return 'MP3';
    if (s == 'aac') return 'AAC';
    if (s == 'alac') return 'ALAC';
    if (s == 'm4a' || s == 'mp4' || s == 'aac-lc' || s == 'aac-he') return 'M4A';
    if (s == 'wav' || s == 'wave') return 'WAV';
    if (s == 'wma') return 'WMA';
    if (s == 'aiff' || s == 'aif') return 'AIFF';
    if (s == 'dsf' || s == 'dsdiff') return 'DSD';
    if (s.startsWith('eac3') || s == 'ac3' || s == 'ac4') return 'M4A';
    return s.toUpperCase();
  }

  Future<Map<String, dynamic>?> _probeAudioMetadata(
    String filePath, {
    String? fallbackQuality,
  }) async {
    if (!_supportsAudioMetadataProbe(filePath)) {
      return null;
    }

    try {
      final result = await PlatformBridge.readFileMetadata(filePath);
      if (result['error'] != null) {
        return null;
      }

      final bitDepth = _readPositiveInt(result['bit_depth']);
      final sampleRate = _readPositiveInt(result['sample_rate']);
      final bitrateKbps = _readPositiveBitrateKbps(result['bitrate']);
      final detectedFormat = _normalizeAudioFormatValue(
        result['audio_codec'] ?? result['format'],
      );
      final quality = _resolveDisplayQuality(
        filePath: filePath,
        bitDepth: bitDepth,
        sampleRate: sampleRate,
        bitrateKbps: bitrateKbps,
        storedQuality: fallbackQuality,
      );
      final composer = normalizeOptionalString(result['composer']?.toString());
      final duration = _readPositiveInt(result['duration']);
      final trackNumber = _readPositiveInt(result['track_number']);
      final totalTracks = _readPositiveInt(result['total_tracks']);
      final discNumber = _readPositiveInt(result['disc_number']);
      final totalDiscs = _readPositiveInt(result['total_discs']);

      if (quality == null &&
          bitDepth == null &&
          sampleRate == null &&
          bitrateKbps == null &&
          detectedFormat == null &&
          composer == null &&
          duration == null &&
          trackNumber == null &&
          totalTracks == null &&
          discNumber == null &&
          totalDiscs == null) {
        return null;
      }

      return {
        'quality': quality,
        'bitDepth': bitDepth,
        'sampleRate': sampleRate,
        'bitrateKbps': bitrateKbps,
        'format': detectedFormat,
        'composer': composer,
        'duration': duration,
        'trackNumber': trackNumber,
        'totalTracks': totalTracks,
        'discNumber': discNumber,
        'totalDiscs': totalDiscs,
      };
    } catch (e) {
      _historyLog.d('Audio metadata probe failed for $filePath: $e');
      return null;
    }
  }

  Future<void> _backfillAudioMetadata(
    List<DownloadHistoryItem> items, {
    required int maxItems,
    required SharedPreferences prefs,
  }) async {
    if (_isAudioMetadataBackfillInProgress || items.isEmpty) {
      return;
    }
    _isAudioMetadataBackfillInProgress = true;

    try {
      final candidateIndexes = <int>[];
      for (var i = 0; i < items.length; i++) {
        if (_shouldBackfillAudioMetadata(items[i])) {
          candidateIndexes.add(i);
        }
      }

      if (candidateIndexes.isEmpty) {
        await prefs.remove(_startupAudioCursorKey);
        return;
      }

      final startCursor = _readStartupCursor(
        prefs,
        _startupAudioCursorKey,
        candidateIndexes.length,
      );
      final endCursor = (startCursor + maxItems).clamp(
        0,
        candidateIndexes.length,
      );
      final selectedIndexes = candidateIndexes.sublist(startCursor, endCursor);

      if (selectedIndexes.isEmpty) {
        await prefs.remove(_startupAudioCursorKey);
        return;
      }

      List<DownloadHistoryItem>? updatedItems;
      final persistedUpdates = <Map<String, dynamic>>[];
      var refreshedCount = 0;

      for (final index in selectedIndexes) {
        final item = items[index];

        final probed = await _probeAudioMetadata(
          item.filePath,
          fallbackQuality: item.quality,
        );
        if (probed == null) {
          continue;
        }

        final resolvedQuality = normalizeOptionalString(
          probed['quality'] as String?,
        );
        final resolvedBitDepth = probed['bitDepth'] as int?;
        final resolvedSampleRate = probed['sampleRate'] as int?;
        final resolvedFormat = probed['format'] as String?;
        final resolvedBitrate = probed['bitrateKbps'] as int?;
        final resolvedComposer = normalizeOptionalString(
          probed['composer'] as String?,
        );
        final resolvedDuration = probed['duration'] as int?;
        final resolvedTrackNumber = probed['trackNumber'] as int?;
        final resolvedTotalTracks = probed['totalTracks'] as int?;
        final resolvedDiscNumber = probed['discNumber'] as int?;

        final resolvedTotalDiscs = probed['totalDiscs'] as int?;

        final qualityChanged =
            resolvedQuality != null && resolvedQuality != item.quality;
        final bitDepthChanged =
            resolvedBitDepth != null && resolvedBitDepth != item.bitDepth;
        final sampleRateChanged =
            resolvedSampleRate != null && resolvedSampleRate != item.sampleRate;
        final formatChanged =
            resolvedFormat != null && resolvedFormat != item.format;
        final bitrateChanged =
            resolvedBitrate != null && resolvedBitrate != item.bitrate;
        final composerChanged =
            resolvedComposer != null && resolvedComposer != item.composer;
        final durationChanged =
            resolvedDuration != null && resolvedDuration != item.duration;
        final trackNumberChanged =
            resolvedTrackNumber != null &&
            resolvedTrackNumber != item.trackNumber;
        final totalTracksChanged =
            resolvedTotalTracks != null &&
            resolvedTotalTracks != item.totalTracks;
        final discNumberChanged =
            resolvedDiscNumber != null && resolvedDiscNumber != item.discNumber;
        final totalDiscsChanged =
            resolvedTotalDiscs != null && resolvedTotalDiscs != item.totalDiscs;

        if (!qualityChanged &&
            !bitDepthChanged &&
            !sampleRateChanged &&
            !formatChanged &&
            !bitrateChanged &&
            !composerChanged &&
            !durationChanged &&
            !trackNumberChanged &&
            !totalTracksChanged &&
            !discNumberChanged &&
            !totalDiscsChanged) {
          continue;
        }

        final updated = item.copyWith(
          quality: resolvedQuality,
          bitDepth: resolvedBitDepth,
          sampleRate: resolvedSampleRate,
          bitrate: resolvedBitrate,
          format: resolvedFormat,
          composer: resolvedComposer,
          duration: resolvedDuration,
          trackNumber: resolvedTrackNumber,
          totalTracks: resolvedTotalTracks,
          discNumber: resolvedDiscNumber,
          totalDiscs: resolvedTotalDiscs,
        );
        updatedItems ??= [...items];
        updatedItems[index] = updated;
        persistedUpdates.add(updated.toJson());
        refreshedCount++;
      }

      if (persistedUpdates.isNotEmpty && updatedItems != null) {
        await _db.upsertBatch(persistedUpdates);
        state = state.copyWith(
          items: updatedItems,
          loadedIndexVersion: state.loadedIndexVersion + 1,
          lookupItems: _lookupItemsWithUpdates(updatedItems),
        );
      }

      await _writeStartupCursor(
        prefs,
        _startupAudioCursorKey,
        endCursor,
        candidateIndexes.length,
      );

      if (refreshedCount > 0) {
        _historyLog.i(
          'Audio metadata backfill refreshed $refreshedCount items',
        );
      }
    } finally {
      _isAudioMetadataBackfillInProgress = false;
    }
  }

  Future<void> reloadFromStorage() async {
    await _loadFromDatabase();
  }

  void _bumpHistoryRevision() {
    state = state.copyWith(loadedIndexVersion: state.loadedIndexVersion + 1);
  }

  Future<DownloadHistoryItem> _putInMemoryHistory(
    DownloadHistoryItem item,
  ) async {
    DownloadHistoryItem? existing;
    if (item.spotifyId != null && item.spotifyId!.isNotEmpty) {
      existing = state.getBySpotifyId(item.spotifyId!);
    }
    if (existing == null && item.isrc != null && item.isrc!.isNotEmpty) {
      existing = state.getByIsrc(item.isrc!);
    }
    if (existing == null) {
      final json = await _db.findExisting(
        spotifyId: item.spotifyId,
        isrc: item.isrc,
      );
      if (json != null) {
        existing = DownloadHistoryItem.fromJson(json);
      }
    }
    if (existing == null) {
      final json = await _db.findByTrackAndArtist(
        item.trackName,
        item.artistName,
      );
      if (json != null) {
        existing = DownloadHistoryItem.fromJson(json);
      }
    }

    final incomingItem = existing != null && existing.id != item.id
        ? DownloadHistoryItem.fromJson(item.toJson()..['id'] = existing.id)
        : item;
    final mergedItem = existing == null
        ? incomingItem
        : incomingItem.copyWith(
            trackNumber: item.trackNumber ?? existing.trackNumber,
            totalTracks: item.totalTracks ?? existing.totalTracks,
            discNumber: item.discNumber ?? existing.discNumber,
            totalDiscs: item.totalDiscs ?? existing.totalDiscs,
            genre:
                normalizeOptionalString(item.genre) ??
                normalizeOptionalString(existing.genre),
            composer:
                normalizeOptionalString(item.composer) ??
                normalizeOptionalString(existing.composer),
            label:
                normalizeOptionalString(item.label) ??
                normalizeOptionalString(existing.label),
            copyright:
                normalizeOptionalString(item.copyright) ??
                normalizeOptionalString(existing.copyright),
          );

    if (existing != null) {
      final updatedItems = state.items
          .where((i) => i.id != existing!.id)
          .toList();
      updatedItems.insert(0, mergedItem);
      final updatedLookupItems = state.lookupItems
          .where((i) => i.id != existing!.id)
          .toList(growable: false);
      state = state.copyWith(
        items: updatedItems,
        lookupItems: [mergedItem, ...updatedLookupItems],
      );
      _historyLog.d('Updated existing history entry: ${mergedItem.trackName}');
    } else {
      state = state.copyWith(
        items: [mergedItem, ...state.items],
        totalCount: state.totalCount + 1,
        lookupItems: [mergedItem, ...state.lookupItems],
      );
      _historyLog.d('Added new history entry: ${mergedItem.trackName}');
    }
    return mergedItem;
  }

  List<DownloadHistoryItem> _lookupItemsWithUpdates(
    Iterable<DownloadHistoryItem> updates, {
    Set<String> deletedIds = const <String>{},
  }) {
    final byId = <String, DownloadHistoryItem>{
      for (final item in state.lookupItems)
        if (!deletedIds.contains(item.id)) item.id: item,
    };
    for (final item in updates) {
      if (!deletedIds.contains(item.id)) {
        byId[item.id] = item;
      }
    }
    return byId.values.toList(growable: false);
  }

  void addToHistory(DownloadHistoryItem item) {
    unawaited(
      () async {
        final mergedItem = await _putInMemoryHistory(item);
        await _db.upsert(mergedItem.toJson());
        _bumpHistoryRevision();
      }().catchError((Object e, StackTrace stack) {
        _historyLog.e('Failed to save to database: $e', e, stack);
      }),
    );
  }

  void adoptNativeHistoryItem(DownloadHistoryItem item) {
    unawaited(
      () async {
        final mergedItem = await _putInMemoryHistory(item);
        await _db.upsert(mergedItem.toJson());
        _bumpHistoryRevision();
      }().catchError((Object e, StackTrace stack) {
        _historyLog.e('Failed to adopt native history item: $e', e, stack);
      }),
    );
  }

  Future<void> updateVideoPath(String id, String videoPath) async {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final items = [...state.items];
    items[index] = items[index].copyWith(videoFilePath: videoPath);
    state = state.copyWith(items: items);
    await _db.updateVideoPath(id, videoPath);
  }


  void removeFromHistory(String id) {
    state = state.copyWith(
      items: state.items.where((item) => item.id != id).toList(),
      totalCount: state.totalCount > 0
          ? state.totalCount - 1
          : state.totalCount,
      lookupItems: state.lookupItems
          .where((item) => item.id != id)
          .toList(growable: false),
    );
    _db
        .deleteById(id)
        .catchError((Object e) {
          _historyLog.e('Failed to delete from database: $e');
          return 0;
        })
        .then((_) {
          _bumpHistoryRevision();
        });
  }

  Future<void> deleteDownload(DownloadHistoryItem item) async {
    final matchKey = HistoryDatabase.matchKeyFor(item.trackName, item.artistName);
    final relatedItems = state.items.where((i) {
      if (i.id == item.id) return true;
      return HistoryDatabase.matchKeyFor(i.trackName, i.artistName) == matchKey;
    }).toList();

    // Remove from history memory state immediately (UI updates right away)
    final idsToRemove = relatedItems.map((e) => e.id).toSet();
    state = state.copyWith(
      items: state.items.where((i) => !idsToRemove.contains(i.id)).toList(),
      totalCount: state.totalCount > idsToRemove.length ? state.totalCount - idsToRemove.length : 0,
      lookupItems: state.lookupItems.where((i) => !idsToRemove.contains(i.id)).toList(growable: false),
    );
    _bumpHistoryRevision();

    _historyLog.i('Deleting all versions of: ${item.trackName} - ${item.artistName} (${relatedItems.length} items)');

    // Delete files in parallel (non-blocking)
    unawaited(Future.wait(relatedItems.expand((r) => [
      if (r.filePath.isNotEmpty)
        HardDeleteUtils.deleteFileAndCleanupFolder(r.filePath)
            .catchError((e) => _historyLog.w('Failed to delete file ${r.filePath}: $e')),
      if (r.videoFilePath != null && r.videoFilePath!.isNotEmpty)
        HardDeleteUtils.deleteFileAndCleanupFolder(r.videoFilePath!)
            .catchError((e) => _historyLog.w('Failed to delete video file ${r.videoFilePath}: $e')),
    ])));

    // Database cleanup and provider notifications (background, non-blocking)
    unawaited(_cleanupAfterDelete(item, relatedItems));
  }

  Future<void> _cleanupAfterDelete(DownloadHistoryItem item, List<DownloadHistoryItem> relatedItems) async {
    try {
      await _db.deleteByTrackMatch(item.trackName, item.artistName);
      final paths = relatedItems.where((i) => i.filePath.isNotEmpty).map((i) => i.filePath).toList();
      if (paths.isNotEmpty) {
        await LibraryDatabase.instance.deleteByPaths(paths);
      }
    } catch (e) {
      _historyLog.e('Database cleanup failed: $e');
    }
    try {
      ref.read(localLibraryProvider.notifier).bumpVersion();
    } catch (e) {
      _historyLog.w('Failed to bump local library version: $e');
    }
    try {
      ref.read(libraryCollectionsProvider.notifier).updateTrackPaths(
        track: item.toTrack(),
        audioPath: null,
        coverPath: null,
      );
    } catch (e) {
      _historyLog.w('Failed to notify collections provider of deletion: $e');
    }
  }

  void removeBySpotifyId(String spotifyId) {
    state = state.copyWith(
      items: state.items.where((item) => item.spotifyId != spotifyId).toList(),
      lookupItems: state.lookupItems
          .where((item) => item.spotifyId != spotifyId)
          .toList(growable: false),
    );
    unawaited(
      () async {
        final deleted = await _db.deleteBySpotifyId(spotifyId);
        final totalCount = await _db.getCount();
        state = state.copyWith(totalCount: totalCount);
        _bumpHistoryRevision();
        _historyLog.d('Removed $deleted item(s) with spotifyId: $spotifyId');
      }().catchError((Object e, StackTrace stack) {
        _historyLog.e('Failed to delete from database: $e', e, stack);
      }),
    );
  }

  DownloadHistoryItem? getBySpotifyId(String spotifyId) {
    return state.getBySpotifyId(spotifyId);
  }

  DownloadHistoryItem? getByIsrc(String isrc) {
    return state.getByIsrc(isrc);
  }

  Future<DownloadHistoryItem?> getBySpotifyIdAsync(String spotifyId) async {
    final inMemory = state.getBySpotifyId(spotifyId);
    if (inMemory != null) return inMemory;

    final json = await _db.getBySpotifyId(spotifyId);
    if (json == null) return null;
    return DownloadHistoryItem.fromJson(json);
  }

  Future<DownloadHistoryItem?> getByIsrcAsync(String isrc) async {
    final inMemory = state.getByIsrc(isrc);
    if (inMemory != null) return inMemory;

    final json = await _db.getByIsrc(isrc);
    if (json == null) return null;
    return DownloadHistoryItem.fromJson(json);
  }

  Future<DownloadHistoryItem?> findByTrackAndArtistAsync(
    String trackName,
    String artistName,
  ) async {
    final inMemory = state.findByTrackAndArtist(trackName, artistName);
    if (inMemory != null) return inMemory;

    final json = await _db.findByTrackAndArtist(trackName, artistName);
    if (json == null) return null;
    return DownloadHistoryItem.fromJson(json);
  }

  Future<DownloadHistoryItem?> findExistingTrackAsync(
    HistoryLookupRequest request,
  ) async {
    final bySpotifyId = state.getBySpotifyId(request.spotifyId);
    if (bySpotifyId != null) return bySpotifyId;

    final isrc = request.isrc?.trim();
    if (isrc != null && isrc.isNotEmpty) {
      final byIsrc = state.getByIsrc(isrc);
      if (byIsrc != null) return byIsrc;
    }

    final byTrackArtist = state.findByTrackAndArtist(
      request.trackName,
      request.artistName,
    );
    if (byTrackArtist != null) return byTrackArtist;

    final json = await _db.findExistingTrack(request);
    if (json == null) return null;
    return DownloadHistoryItem.fromJson(json);
  }

  Future<({DownloadHistoryItem item, int index})?> _historyItemForUpdate(
    String id,
  ) async {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      return (item: state.items[index], index: index);
    }

    final json = await _db.getById(id);
    if (json == null) return null;
    return (item: DownloadHistoryItem.fromJson(json), index: -1);
  }

  Future<void> updateAudioMetadataForItem({
    required String id,
    String? quality,
    int? bitDepth,
    int? sampleRate,
    int? bitrate,
    String? format,
    int? trackNumber,
    int? totalTracks,
    int? discNumber,
    int? totalDiscs,
    int? duration,
    String? composer,
  }) async {
    final target = await _historyItemForUpdate(id);
    if (target == null) {
      _historyLog.w(
        'Cannot update audio metadata for missing history item: $id',
      );
      return;
    }

    final current = target.item;
    final updated = current.copyWith(
      quality: quality,
      bitDepth: bitDepth,
      sampleRate: sampleRate,
      bitrate: bitrate,
      format: format,
      trackNumber: trackNumber,
      totalTracks: totalTracks,
      discNumber: discNumber,
      totalDiscs: totalDiscs,
      duration: duration,
      composer: composer,
    );

    if (updated.quality == current.quality &&
        updated.bitDepth == current.bitDepth &&
        updated.sampleRate == current.sampleRate &&
        updated.bitrate == current.bitrate &&
        updated.format == current.format &&
        updated.trackNumber == current.trackNumber &&
        updated.totalTracks == current.totalTracks &&
        updated.discNumber == current.discNumber &&
        updated.totalDiscs == current.totalDiscs &&
        updated.duration == current.duration &&
        updated.composer == current.composer) {
      return;
    }

    final updatedItems = target.index >= 0
        ? ([...state.items]..[target.index] = updated)
        : state.items;
    state = state.copyWith(
      items: updatedItems,

      lookupItems: _lookupItemsWithUpdates([updated]),
    );
    await _db.upsert(updated.toJson());
    _bumpHistoryRevision();
  }

  Future<void> updateMetadataForItem({
    required String id,
    required String trackName,
    required String artistName,
    required String albumName,
    String? albumArtist,
    String? isrc,
    int? trackNumber,
    int? totalTracks,
    int? discNumber,
    int? totalDiscs,
    String? releaseDate,
    String? genre,
    String? composer,
    String? label,
    String? copyright,
  }) async {
    final target = await _historyItemForUpdate(id);
    if (target == null) {
      _historyLog.w('Cannot update metadata for missing history item: $id');
      return;
    }

    final current = target.item;
    final updated = current.copyWith(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      albumArtist: albumArtist,
      isrc: isrc,
      trackNumber: trackNumber,
      totalTracks: totalTracks,
      discNumber: discNumber,
      totalDiscs: totalDiscs,
      releaseDate: releaseDate,
      genre: genre,
      composer: composer,
      label: label,
      copyright: copyright,
    );

    final updatedItems = target.index >= 0
        ? ([...state.items]..[target.index] = updated)
        : state.items;
    state = state.copyWith(
      items: updatedItems,
      lookupItems: _lookupItemsWithUpdates([updated]),
    );
    await _db.upsert(updated.toJson());
    _bumpHistoryRevision();
  }

  static const _audioExtensions = [
    '.flac',
    '.m4a',
    '.mp3',
    '.opus',
    '.ogg',
    '.wav',
    '.aac',
  ];

  Future<String?> _findConvertedSibling(String originalPath) async {
    final dotIndex = originalPath.lastIndexOf('.');
    if (dotIndex < 0) return null;
    final basePath = originalPath.substring(0, dotIndex);
    final originalExt = originalPath.substring(dotIndex).toLowerCase();

    for (final ext in _audioExtensions) {
      if (ext == originalExt) continue;
      final candidatePath = '$basePath$ext';
      try {
        if (await fileExists(candidatePath)) return candidatePath;
      } catch (e) {}
    }
    return null;
  }

  Future<
    ({
      List<String> orphanedIds,
      Map<String, String> replacementPaths,
      Map<String, String> pathById,
    })
  >
  _inspectOrphanedEntries(List<Map<String, dynamic>> entries) async {
    final orphanedIds = <String>[];
    final replacementPaths = <String, String>{};
    final pathById = <String, String>{};
    const checkChunkSize = 16;

    for (var i = 0; i < entries.length; i += checkChunkSize) {
      final end = (i + checkChunkSize < entries.length)
          ? i + checkChunkSize
          : entries.length;
      final chunk = entries.sublist(i, end);

      final checks = await Future.wait<MapEntry<String, bool>?>(
        chunk.map((entry) async {
          final id = entry['id'] as String;
          final filePath = entry['file_path'] as String?;
          if (filePath == null || filePath.isEmpty) return null;
          pathById[id] = filePath;
          try {
            if (await fileExists(filePath)) return MapEntry(id, true);

            final sibling = await _findConvertedSibling(filePath);
            if (sibling != null) {
              _historyLog.i(
                'Found converted sibling for $id: $filePath -> $sibling',
              );
              replacementPaths[id] = sibling;
              pathById[id] = sibling;
              return MapEntry(id, true);
            }

            return MapEntry(id, false);
          } catch (e) {
            _historyLog.w('Error checking file existence for $id: $e');
            return MapEntry(id, false);
          }
        }),
      );

      for (final check in checks) {
        if (check == null || check.value) continue;
        orphanedIds.add(check.key);
        _historyLog.d(
          'Found orphaned entry: ${check.key} (${pathById[check.key] ?? ''})',
        );
      }
    }

    return (
      orphanedIds: orphanedIds,
      replacementPaths: replacementPaths,
      pathById: pathById,
    );
  }

  void _applyHistoryPathAndDeletionChanges({
    required List<String> deletedIds,
    required Map<String, String> replacementPaths,
  }) {
    if (deletedIds.isEmpty && replacementPaths.isEmpty) {
      return;
    }
    final deletedSet = deletedIds.toSet();
    final updatedItems = <DownloadHistoryItem>[];
    for (final item in state.items) {
      if (deletedSet.contains(item.id)) {
        continue;
      }
      final replacementPath = replacementPaths[item.id];
      if (replacementPath != null && replacementPath != item.filePath) {
        updatedItems.add(item.copyWith(filePath: replacementPath));
      } else {
        updatedItems.add(item);
      }
    }
    state = state.copyWith(
      items: updatedItems,
      loadedIndexVersion: state.loadedIndexVersion + 1,
      lookupItems: _lookupItemsWithUpdates(
        updatedItems,
        deletedIds: deletedSet,
      ),
      totalCount: max(0, state.totalCount - deletedSet.length),
    );
  }

  Future<int> _cleanupOrphanedDownloadsIncremental({
    required int maxItems,
    required SharedPreferences prefs,
  }) async {
    final cursor = prefs.getInt(_startupOrphanCursorKey) ?? 0;
    final safeCursor = cursor < 0 ? 0 : cursor;
      final entries = await _db.getEntriesWithPathsPage(maxItems, safeCursor);
    if (entries.isEmpty) {
      await prefs.remove(_startupOrphanCursorKey);
      return 0;
    }

    final result = await _inspectOrphanedEntries(entries);
    for (final replacement in result.replacementPaths.entries) {
      await _db.updateFilePath(replacement.key, replacement.value);
    }

    final deletedCount = result.orphanedIds.isEmpty
        ? 0
        : await _db.deleteByIds(result.orphanedIds);

    _applyHistoryPathAndDeletionChanges(
      deletedIds: result.orphanedIds,
      replacementPaths: result.replacementPaths,
    );

    if (entries.length < maxItems) {
      await prefs.remove(_startupOrphanCursorKey);
    } else {
      final nextCursor =
          safeCursor + entries.length - result.orphanedIds.length;
      await prefs.setInt(_startupOrphanCursorKey, nextCursor);
    }

    if (deletedCount > 0 || result.replacementPaths.isNotEmpty) {
      _historyLog.i(
        'Startup orphan cleanup pass: removed=$deletedCount, repaired=${result.replacementPaths.length}, checked=${entries.length}',
      );
    }
    return deletedCount;
  }

  Future<int> cleanupOrphanedDownloads() async {
    _historyLog.i('Starting orphaned downloads cleanup...');
    final orphanedIds = <String>[];
    final replacementPaths = <String, String>{};
    const pageSize = 256;
    var offset = 0;

    while (true) {
      final entries = await _db.getEntriesWithPathsPage(pageSize, offset);
      if (entries.isEmpty) {
        break;
      }

      final result = await _inspectOrphanedEntries(entries);
      orphanedIds.addAll(result.orphanedIds);
      replacementPaths.addAll(result.replacementPaths);

      if (entries.length < pageSize) {
        break;
      }
      offset += entries.length - result.orphanedIds.length;
    }

    for (final replacement in replacementPaths.entries) {
      await _db.updateFilePath(replacement.key, replacement.value);
    }

    if (orphanedIds.isEmpty && replacementPaths.isEmpty) {
      _historyLog.i('No orphaned entries found');
      return 0;
    }

    final deletedCount = orphanedIds.isEmpty
        ? 0
        : await _db.deleteByIds(orphanedIds);
    _applyHistoryPathAndDeletionChanges(
      deletedIds: orphanedIds,
      replacementPaths: replacementPaths,
    );

    _historyLog.i(
      'Cleaned up $deletedCount orphaned entries and repaired ${replacementPaths.length} paths',
    );
    return deletedCount;
  }

  void clearHistory() {
    state = DownloadHistoryState(loadedIndexVersion: state.loadedIndexVersion);
    _db
        .clearAll()
        .then((_) {
          _bumpHistoryRevision();
        })
        .catchError((Object e) {
          _historyLog.e('Failed to clear database: $e');
        });
  }

  Future<int> getDatabaseCount() async {
    return await _db.getCount();
  }
}