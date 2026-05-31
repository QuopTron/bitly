part of 'queue_tab.dart';

enum LibraryItemSource { downloaded, local }

class UnifiedLibraryItem {
  final String id;
  final String trackName;
  final String artistName;
  final String albumName;
  final String? coverUrl;
  final String? localCoverPath;
  final String filePath;
  final String? quality;
  final DateTime addedAt;
  final LibraryItemSource source;

  final DownloadHistoryItem? historyItem;
  final LocalLibraryItem? localItem;
  final CollectionTrackEntry? lovedEntry;
  final DownloadItem? queueItem;
  final List<Track>? alternateSources;
  final ValueChanged<Track>? onSourceSelected;
  final List<SourceInfo>? alternateSourceInfo;

  UnifiedLibraryItem({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    this.coverUrl,
    this.localCoverPath,
    required this.filePath,
    this.quality,
    required this.addedAt,
    required this.source,
    this.historyItem,
    this.localItem,
    this.lovedEntry,
    this.queueItem,
    this.alternateSources,
    this.onSourceSelected,
    this.alternateSourceInfo,
  });

  factory UnifiedLibraryItem.fromDownloadHistory(DownloadHistoryItem item) {
    return UnifiedLibraryItem(
      id: 'dl_${item.id}',
      trackName: item.trackName,
      artistName: item.artistName,
      albumName: item.albumName,
      coverUrl: item.coverUrl,
      filePath: item.filePath,
      quality: buildDisplayAudioQuality(
        bitDepth: item.bitDepth,
        sampleRate: item.sampleRate,
        storedQuality: item.quality,
      ),
       addedAt: item.downloadedAt ?? DateTime.now(),
      source: LibraryItemSource.downloaded,
      historyItem: item,
    );
  }

  factory UnifiedLibraryItem.fromLocalLibrary(LocalLibraryItem item) {
    String? quality;
    if (item.bitrate != null && item.bitrate! > 0) {
      quality = buildDisplayAudioQuality(
        bitrateKbps: item.bitrate,
        format: item.format,
      );
    } else if (item.bitDepth != null &&
        item.bitDepth! > 0 &&
        item.sampleRate != null) {
      quality = buildDisplayAudioQuality(
        bitDepth: item.bitDepth,
        sampleRate: item.sampleRate,
      );
    }
    return UnifiedLibraryItem(
      id: 'local_${item.id}',
      trackName: item.trackName,
      artistName: item.artistName,
      albumName: item.albumName,
      coverUrl: null,
      localCoverPath: item.coverPath,
      filePath: item.filePath,
      quality: quality,
      addedAt: item.fileModTime != null
          ? DateTime.fromMillisecondsSinceEpoch(item.fileModTime!)
          : item.scannedAt,
      source: LibraryItemSource.local,
      localItem: item,
    );
  }

  factory UnifiedLibraryItem.fromDownloadItem(DownloadItem item) {
    return UnifiedLibraryItem(
      id: 'q_${item.id}',
      trackName: item.track.name,
      artistName: item.track.artistName,
      albumName: item.track.albumName,
      coverUrl: item.track.coverUrl,
      filePath: '',
      quality: item.qualityOverride,
      addedAt: item.createdAt,
      source: LibraryItemSource.downloaded,
      queueItem: item,
    );
  }

  bool get hasCover =>
      coverUrl != null ||
      (localCoverPath != null && localCoverPath!.isNotEmpty);

  String? get albumArtist => historyItem?.albumArtist ?? localItem?.albumArtist;

  String? get releaseDate => historyItem?.releaseDate ?? localItem?.releaseDate;

  String? get genre => historyItem?.genre ?? localItem?.genre;

  int? get trackNumber => historyItem?.trackNumber ?? localItem?.trackNumber;

  int? get discNumber => historyItem?.discNumber ?? localItem?.discNumber;

  String? get isrc => historyItem?.isrc ?? localItem?.isrc;

  String? get label => historyItem?.label ?? localItem?.label;

  String get searchKey =>
      '${trackName.toLowerCase()}|${artistName.toLowerCase()}|${albumName.toLowerCase()}';
  String get albumKey =>
      '${albumName.toLowerCase()}|${artistName.toLowerCase()}';

  /// Returns the collection key used to match this item against playlist
  /// entries and loved tracks. Uses the same logic as [trackCollectionKey] from
  /// the collections provider: prefer ISRC, fall back to normalizeSource(source):id.
  String get collectionKey {
    if (historyItem != null) {
      final isrc = historyItem!.isrc?.trim();
      if (isrc != null && isrc.isNotEmpty) return 'isrc:${isrc.toUpperCase()}';
    } else if (localItem != null) {
      final isrc = localItem!.isrc?.trim();
      if (isrc != null && isrc.isNotEmpty) return 'isrc:${isrc.toUpperCase()}';
    }
    return _collectionKeyNoIsrc;
  }

  /// Fallback key when ISRC is not available.
  /// Uses [normalizeSource] on the service for consistency with [trackCollectionKey],
  /// and uses [id] (which may include a `dl_` prefix for downloaded items)
  /// so the key matches what [trackCollectionKey] produces for the Track
  /// constructed from this item (see [_buildUnifiedLibraryItem]).
  String get _collectionKeyNoIsrc {
    if (historyItem != null) {
      final source = historyItem!.service;
      final ns = source != null && source.trim().isNotEmpty
          ? normalizeSource(source.trim())
          : 'builtin';
      return '$ns:$id';
    }
    if (localItem != null) {
      return 'local:${localItem!.id}';
    }
    return 'builtin:$id';
  }

  Track toTrack() {
    if (historyItem != null) {
      final h = historyItem!;
      return Track(
        id: h.id,
        name: h.trackName,
        artistName: h.artistName,
        albumName: h.albumName,
        albumArtist: h.albumArtist,
        coverUrl: h.coverUrl,
        isrc: h.isrc,
        duration: h.duration ?? 0,
        trackNumber: h.trackNumber,
        discNumber: h.discNumber,
        releaseDate: h.releaseDate,
        source: h.service,
        audioQuality: h.quality,
        codec: h.format,
        bitDepth: h.bitDepth,
        sampleRate: h.sampleRate,
      );
    }
    if (localItem != null) {
      final l = localItem!;
      return Track(
        id: l.id,
        name: l.trackName,
        artistName: l.artistName,
        albumName: l.albumName,
        albumArtist: l.albumArtist,
        coverUrl: l.coverPath,
        isrc: l.isrc,
        duration: l.duration ?? 0,
        trackNumber: l.trackNumber,
        discNumber: l.discNumber,
        releaseDate: l.releaseDate,
        source: 'local',
        codec: l.format,
        bitDepth: l.bitDepth,
        sampleRate: l.sampleRate,
      );
    }
    return Track(
      id: id,
      name: trackName,
      artistName: artistName,
      albumName: albumName,
      coverUrl: coverUrl,
      duration: 0,
    );
  }
}

class _GroupedAlbum {
  final String albumName;
  final String artistName;
  final String? coverUrl;
  final String? coverPath;
  final String? sampleFilePath;
  final List<dynamic> tracks;
  final int? trackCount;
  final DateTime latestDownload;
  final String searchKey;

  _GroupedAlbum({
    required this.albumName,
    required this.artistName,
    this.coverUrl,
    this.coverPath,
    this.sampleFilePath,
    required this.tracks,
    this.trackCount,
    required this.latestDownload,
  }) : searchKey = '${albumName.toLowerCase()}|${artistName.toLowerCase()}';

  String get key => '$albumName|$artistName';

  int get displayTrackCount => trackCount ?? tracks.length;
}

class _HistoryStats {
  final Map<String, int> albumCounts;
  final List<_GroupedAlbum> groupedAlbums;
  final int albumCount;
  final int singleTracks;

  const _HistoryStats({
    required this.albumCounts,
    required this.groupedAlbums,
    required this.albumCount,
    required this.singleTracks,
  });
}

class _FilterContentData {
  final List<DownloadHistoryItem> historyItems;
  final List<UnifiedLibraryItem> unifiedItems;
  final List<UnifiedLibraryItem> filteredUnifiedItems;
  final List<_GroupedAlbum> filteredGroupedAlbums;
  final bool showFilteringIndicator;
  final int? totalTrackCountOverride;
  final int? totalAlbumCountOverride;

  const _FilterContentData({
    required this.historyItems,
    required this.unifiedItems,
    required this.filteredUnifiedItems,
    required this.filteredGroupedAlbums,
    required this.showFilteringIndicator,
    this.totalTrackCountOverride,
    this.totalAlbumCountOverride,
  });

  int get totalTrackCount =>
      totalTrackCountOverride ?? filteredUnifiedItems.length;
  int get totalAlbumCount =>
      totalAlbumCountOverride ?? filteredGroupedAlbums.length;
}

class _QueueLibraryPageRequest {
  final String filterMode;
  final int limit;
  final String searchQuery;
  final String? filterQuality;
  final String? filterFormat;
  final String? filterMetadata;
  final String sortMode;
  final bool localLibraryEnabled;

  const _QueueLibraryPageRequest({
    required this.filterMode,
    required this.limit,
    required this.searchQuery,
    required this.filterQuality,
    required this.filterFormat,
    required this.filterMetadata,
    required this.sortMode,
    required this.localLibraryEnabled,
  });

  QueueLibraryDbQuery toDbQuery() => QueueLibraryDbQuery(
    limit: limit,
    filterMode: filterMode,
    searchQuery: searchQuery,
    source: null,
    quality: filterQuality,
    format: filterFormat,
    metadata: filterMetadata,
    sortMode: sortMode,
    includeLocal: localLibraryEnabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _QueueLibraryPageRequest &&
          filterMode == other.filterMode &&
          limit == other.limit &&
          searchQuery == other.searchQuery &&
          filterQuality == other.filterQuality &&
          filterFormat == other.filterFormat &&
          filterMetadata == other.filterMetadata &&
          sortMode == other.sortMode &&
          localLibraryEnabled == other.localLibraryEnabled;

  @override
  int get hashCode => Object.hash(
    filterMode,
    limit,
    searchQuery,
    filterQuality,
    filterFormat,
    filterMetadata,
    sortMode,
    localLibraryEnabled,
  );
}

class _QueueLibraryCountsRequest {
  final String searchQuery;
  final String? filterQuality;
  final String? filterFormat;
  final String? filterMetadata;
  final bool localLibraryEnabled;

  const _QueueLibraryCountsRequest({
    required this.searchQuery,
    required this.filterQuality,
    required this.filterFormat,
    required this.filterMetadata,
    required this.localLibraryEnabled,
  });

  QueueLibraryDbQuery toDbQuery() => QueueLibraryDbQuery(
    searchQuery: searchQuery,
    source: null,
    quality: filterQuality,
    format: filterFormat,
    metadata: filterMetadata,
    includeLocal: localLibraryEnabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _QueueLibraryCountsRequest &&
          searchQuery == other.searchQuery &&
          filterQuality == other.filterQuality &&
          filterFormat == other.filterFormat &&
          filterMetadata == other.filterMetadata &&
          localLibraryEnabled == other.localLibraryEnabled;

  @override
  int get hashCode => Object.hash(
    searchQuery,
    filterQuality,
    filterFormat,
    filterMetadata,
    localLibraryEnabled,
  );
}

class _QueueLibraryPageData {
  final List<UnifiedLibraryItem> items;
  final List<DownloadHistoryItem> historyItems;
  final List<LocalLibraryItem> localItems;
  final List<_GroupedAlbum> groupedAlbums;

  const _QueueLibraryPageData({
    this.items = const [],
    this.historyItems = const [],
    this.localItems = const [],
    this.groupedAlbums = const [],
  });

  _FilterContentData toFilterContentData(
    LibraryCollectionsState collectionState, {
    int? totalTrackCount,
    int? totalAlbumCount,
  }) {
    final filteredItems = !collectionState.hasPlaylistTracks
        ? items
        : items
              .where(
                (item) =>
                    !collectionState.isTrackInAnyPlaylist(item.collectionKey),
              )
              .toList(growable: false);
    return _FilterContentData(
      historyItems: historyItems,
      unifiedItems: items,
      filteredUnifiedItems: filteredItems,
      filteredGroupedAlbums: groupedAlbums,
      showFilteringIndicator: false,
      totalTrackCountOverride: totalTrackCount,
      totalAlbumCountOverride: totalAlbumCount,
    );
  }
}

final _queueLibraryPageProvider =
    FutureProvider.family<_QueueLibraryPageData, _QueueLibraryPageRequest>((
      ref,
      request,
    ) async {
      ref.watch(
        downloadHistoryProvider.select((state) => state.loadedIndexVersion),
      );
      ref.watch(
        localLibraryProvider.select((state) => state.loadedIndexVersion),
      );
      final dbQuery = request.toDbQuery();
      if (request.filterMode == 'albums') {
        final rows = await LibraryDatabase.instance.getQueueAlbumPage(query: dbQuery);
        final groupedAlbums = <_GroupedAlbum>[];
        for (final row in rows) {
          final source = row['queue_source'] as String? ?? '';
          final latestMillis = (row['sort_added'] as num?)?.toInt() ?? 0;
          final latest = DateTime.fromMillisecondsSinceEpoch(latestMillis);
          if (source == 'local') {
            groupedAlbums.add(
              _GroupedAlbum(
                albumName: row['album_name'] as String? ?? '',
                artistName: row['artist_name'] as String? ?? '',
                coverPath: row['cover_path'] as String?,
                tracks: const [],
                trackCount: (row['track_count'] as num?)?.toInt() ?? 0,
                latestDownload: latest,
              ),
            );
          } else if (source == 'downloaded') {
            groupedAlbums.add(
              _GroupedAlbum(
                albumName: row['album_name'] as String? ?? '',
                artistName: row['artist_name'] as String? ?? '',
                coverUrl: row['cover_url'] as String?,
                sampleFilePath: row['sample_file_path'] as String? ?? '',
                tracks: const [],
                trackCount: (row['track_count'] as num?)?.toInt() ?? 0,
                latestDownload: latest,
              ),
            );
          }
        }
        return _QueueLibraryPageData(
          groupedAlbums: groupedAlbums,
        );
      }

      final rows = await LibraryDatabase.instance.getQueueTrackPage(query: dbQuery);
      final items = <UnifiedLibraryItem>[];
      final historyItems = <DownloadHistoryItem>[];
      final localItems = <LocalLibraryItem>[];
      for (final row in rows) {
        final source = row['source'] as String? ?? '';
        final itemJson = Map<String, dynamic>.from(row['item'] as Map);
        if (source == 'local') {
          final item = LocalLibraryItem.fromJson(itemJson);
          localItems.add(item);
          items.add(UnifiedLibraryItem.fromLocalLibrary(item));
        } else if (source == 'downloaded') {
          final item = DownloadHistoryItem.fromJson(itemJson);
          historyItems.add(item);
          items.add(UnifiedLibraryItem.fromDownloadHistory(item));
        }
      }
      return _QueueLibraryPageData(
        items: items,
        historyItems: historyItems,
        localItems: localItems,
      );
    });

final _QueueLibraryCountsProvider =
    FutureProvider.family<QueueLibraryCounts, _QueueLibraryCountsRequest>((
      ref,
      request,
    ) async {
      ref.watch(
        downloadHistoryProvider.select((state) => state.loadedIndexVersion),
      );
      ref.watch(
        localLibraryProvider.select((state) => state.loadedIndexVersion),
      );
      return LibraryDatabase.instance.getQueueCounts(query: request.toDbQuery());
    });

class _UnifiedCacheEntry {
  final List<DownloadHistoryItem> historyItems;
  final List<LocalLibraryItem> localItems;
  final Map<String, int> localAlbumCounts;
  final String query;
  final List<UnifiedLibraryItem> items;

  const _UnifiedCacheEntry({
    required this.historyItems,
    required this.localItems,
    required this.localAlbumCounts,
    required this.query,
    required this.items,
  });
}

class _QueueItemIdsSnapshot {
  final List<String> ids;

  const _QueueItemIdsSnapshot(this.ids);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _QueueItemIdsSnapshot && listEquals(ids, other.ids);

  @override
  int get hashCode => Object.hashAll(ids);
}

class FileExistsListenableCache {
  static const int _maxCacheSize = 500;
  static final FileExistsListenableCache instance = FileExistsListenableCache();

  final Map<String, bool> _cache = {};
  final Map<String, ValueNotifier<bool>> _notifiers = {};
  final ValueNotifier<bool> _alwaysMissingNotifier = ValueNotifier(false);
  final Set<String> _pendingChecks = {};

  ValueListenable<bool> listenable(String? filePath) {
    // ... logic remains same ...
    final cleanPath = DownloadedEmbeddedCoverResolver.cleanFilePath(filePath);
    if (cleanPath.isEmpty) return _alwaysMissingNotifier;

    final existingNotifier = _notifiers[cleanPath];
    if (existingNotifier != null) {
      final cached = _cache[cleanPath];
      if (cached != null && existingNotifier.value != cached) {
        existingNotifier.value = cached;
      } else if (cached == null) {
        _startCheck(cleanPath);
      }
      return existingNotifier;
    }

    if (_notifiers.length >= _maxCacheSize) {
      final oldestKey = _notifiers.keys.first;
      _notifiers.remove(oldestKey)?.dispose();
      _cache.remove(oldestKey);
    }

    final notifier = ValueNotifier<bool>(_cache[cleanPath] ?? true);
    _notifiers[cleanPath] = notifier;
    _startCheck(cleanPath);
    return notifier;
  }

  void _startCheck(String cleanPath) {
    if (_pendingChecks.contains(cleanPath)) {
      return;
    }

    final cached = _cache[cleanPath];
    if (cached != null) {
      final notifier = _notifiers[cleanPath];
      if (notifier != null && notifier.value != cached) {
        notifier.value = cached;
      }
      return;
    }

    _pendingChecks.add(cleanPath);
    Future.microtask(() async {
      final exists = await fileExists(cleanPath);
      _pendingChecks.remove(cleanPath);
      _cache[cleanPath] = exists;
      final notifier = _notifiers[cleanPath];
      if (notifier != null && notifier.value != exists) {
        notifier.value = exists;
      }
    });
  }

  void invalidate(String? filePath) {
    final cleanPath = DownloadedEmbeddedCoverResolver.cleanFilePath(filePath);
    if (cleanPath.isEmpty) return;
    _cache.remove(cleanPath);
    _pendingChecks.remove(cleanPath);
    final notifier = _notifiers[cleanPath];
    if (notifier != null) {
      _startCheck(cleanPath);
    }
  }

  void dispose() {
    for (final notifier in _notifiers.values) {
      notifier.dispose();
    }
    _notifiers.clear();
    _alwaysMissingNotifier.dispose();
  }
}

bool _queueHasMetadataValue(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String _queueNormalizedMetadataValue(String? value) {
  return value?.trim().toLowerCase() ?? '';
}

DateTime? _queueParseReleaseDate(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }

  final parsed = DateTime.tryParse(trimmed);
  if (parsed != null) {
    return parsed;
  }

  final yearMatch = RegExp(r'(\d{4})').firstMatch(trimmed);
  if (yearMatch == null) {
    return null;
  }

  final year = int.tryParse(yearMatch.group(1)!);
  if (year == null || year <= 0) {
    return null;
  }
  return DateTime(year);
}

bool _queueMatchesMetadataFilter({
  required String? filterMetadata,
  required String? artistName,
  required String? albumArtist,
  required String? releaseDate,
  required String? genre,
  required int? trackNumber,
  required int? discNumber,
  required String? isrc,
  required String? label,
}) {
  if (filterMetadata == null) {
    return true;
  }

  final hasArtist = _queueHasMetadataValue(artistName);
  final hasAlbumArtist = _queueHasMetadataValue(albumArtist);
  final hasReleaseDate = _queueParseReleaseDate(releaseDate) != null;
  final hasGenre = _queueHasMetadataValue(genre);
  final hasTrackNumber = trackNumber != null && trackNumber > 0;
  final hasDiscNumber = discNumber != null && discNumber > 0;
  final hasLabel = _queueHasMetadataValue(label);
  final hasIncorrectIsrc = _queueHasIncorrectIsrcFormat(isrc);
  final isComplete =
      hasArtist &&
      hasAlbumArtist &&
      hasReleaseDate &&
      hasGenre &&
      hasTrackNumber &&
      hasDiscNumber &&
      hasLabel &&
      !hasIncorrectIsrc;

  switch (filterMetadata) {
    case 'complete':
      return isComplete;
    case 'missing-any':
      return !isComplete;
    case 'missing-year':
      return !hasReleaseDate;
    case 'missing-genre':
      return !hasGenre;
    case 'missing-album-artist':
      return !hasAlbumArtist;
    case 'missing-track-number':
      return !hasTrackNumber;
    case 'missing-disc-number':
      return !hasDiscNumber;
    case 'missing-artist':
      return !hasArtist;
    case 'incorrect-isrc-format':
      return hasIncorrectIsrc;
    case 'missing-label':
      return !hasLabel;
    default:
      return true;
  }
}

bool _queueHasIncorrectIsrcFormat(String? isrc) {
  final raw = isrc?.trim() ?? '';
  if (raw.isEmpty) return false;
  final normalized = raw.toUpperCase().replaceAll(RegExp(r'[-\s]'), '');
  return !RegExp(r'^[A-Z]{2}[A-Z0-9]{3}\d{7}$').hasMatch(normalized);
}

bool _queueUnifiedItemMatchesMetadataFilter(
  UnifiedLibraryItem item,
  String? filterMetadata,
) {
  return _queueMatchesMetadataFilter(
    filterMetadata: filterMetadata,
    artistName: item.artistName,
    albumArtist: item.albumArtist,
    releaseDate: item.releaseDate,
    genre: item.genre,
    trackNumber: item.trackNumber,
    discNumber: item.discNumber,
    isrc: item.isrc,
    label: item.label,
  );
}

int _queueCompareOptionalText(
  String? left,
  String? right, {
  bool descending = false,
}) {
  final normalizedLeft = _queueNormalizedMetadataValue(left);
  final normalizedRight = _queueNormalizedMetadataValue(right);
  final leftEmpty = normalizedLeft.isEmpty;
  final rightEmpty = normalizedRight.isEmpty;

  if (leftEmpty && rightEmpty) {
    return 0;
  }
  if (leftEmpty) {
    return 1;
  }
  if (rightEmpty) {
    return -1;
  }

  final comparison = normalizedLeft.compareTo(normalizedRight);
  return descending ? -comparison : comparison;
}

int _queueCompareOptionalDate(
  DateTime? left,
  DateTime? right, {
  bool descending = false,
}) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }

  final comparison = left.compareTo(right);
  return descending ? -comparison : comparison;
}

Map<String, List<String>> _filterHistoryInIsolate(Map<String, Object> payload) {
  final entries = (payload['entries'] as List).cast<List<Object?>>();
  final albumCounts = Map<String, int>.from(payload['albumCounts'] as Map);
  final query = (payload['query'] as String?) ?? '';
  final hasQuery = query.isNotEmpty;

  final allIds = <String>[];
  final albumIds = <String>[];
  final singleIds = <String>[];

  for (final entry in entries) {
    final id = entry[0] as String;
    final albumKey = entry[1] as String;
    if (hasQuery) {
      final searchKey = entry[2] as String;
      if (!searchKey.contains(query)) {
        continue;
      }
    }

    allIds.add(id);
    final count = albumCounts[albumKey] ?? 0;
    if (count > 1) {
      albumIds.add(id);
    } else if (count == 1) {
      singleIds.add(id);
    }
  }

  return {'all': allIds, 'albums': albumIds, 'singles': singleIds};
}

/// Stores the user's source selection override for a library track card,
/// including playback info (file path, service) so tapping plays the right file.
class _LibrarySourceOverride {
  final Track track;
  final String? filePath;
  final String? service;
  final String? isrc;

  const _LibrarySourceOverride({
    required this.track,
    this.filePath,
    this.service,
    this.isrc,
  });
}

/// Merges multiple sources of the same song (downloaded, liked, queued)
/// into a single card with all sources accessible via the source picker.
class _MergedSongGroup {
  final List<UnifiedLibraryItem> downloadedItems = [];
  final List<CollectionTrackEntry> lovedEntries = [];
  final List<DownloadItem> queueItems = [];

  int _qualityScore(Track track) {
    const qualityOrder = <String>[
      'mqa', 'dsd', '192', '96', '24', 'flac', 'alac',
      '16', '320', 'aac', '256', 'ogg', '128', 'mp3',
    ];
    final q = (track.audioQuality ?? track.codec ?? '').toLowerCase();
    for (var i = 0; i < qualityOrder.length; i++) {
      if (q.contains(qualityOrder[i])) return qualityOrder.length - i;
    }
    return 0;
  }

  /// Pick the best source to be the primary card.
  /// Downloaded items are always preferred (no matter quality).
  /// Falls back to loved > queued, then best quality.
  ({int index, bool isDownloaded, bool isLoved}) _pickPrimary() {
    int bestIdx = 0;
    int bestScore = -1;
    bool bestIsDownloaded = false;
    bool bestIsLoved = false;
    int idx = 0;

    for (final item in downloadedItems) {
      final score = _qualityScore(item.toTrack()) + 100;
      if (score > bestScore) {
        bestIdx = idx;
        bestScore = score;
        bestIsDownloaded = true;
        bestIsLoved = false;
      }
      idx++;
    }

    for (final entry in lovedEntries) {
      final score = _qualityScore(entry.track);
      if (score > bestScore) {
        bestIdx = idx;
        bestScore = score;
        bestIsDownloaded = false;
        bestIsLoved = true;
      }
      idx++;
    }

    for (final qi in queueItems) {
      final score = _qualityScore(qi.track);
      if (score > bestScore) {
        bestIdx = idx;
        bestScore = score;
        bestIsDownloaded = false;
        bestIsLoved = false;
      }
      idx++;
    }

    return (index: bestIdx, isDownloaded: bestIsDownloaded, isLoved: bestIsLoved);
  }

  UnifiedLibraryItem buildItem() {
    final primary = _pickPrimary();
    Track primaryTrack;
    String id;
    String filePath = '';
    DownloadHistoryItem? historyItem;
    LocalLibraryItem? localItem;
    CollectionTrackEntry? lovedEntry;
    DownloadItem? queueItem;
    String? coverUrl;
    String? localCoverPath;
    DateTime addedAt = DateTime.now();
    LibraryItemSource source = LibraryItemSource.local;
    final allTracks = <SourceInfo>[];

    if (primary.isDownloaded && primary.index < downloadedItems.length) {
      final item = downloadedItems[primary.index];
      primaryTrack = item.toTrack();
      id = item.id;
      filePath = item.filePath;
      historyItem = item.historyItem;
      localItem = item.localItem;
      coverUrl = item.coverUrl;
      localCoverPath = item.localCoverPath;
      addedAt = item.addedAt;
      source = historyItem != null ? LibraryItemSource.downloaded : LibraryItemSource.local;
    } else if (primary.isLoved && primary.index - downloadedItems.length < lovedEntries.length) {
      final entry = lovedEntries[primary.index - downloadedItems.length];
      primaryTrack = entry.track;
      id = trackCollectionKey(primaryTrack);
      lovedEntry = entry;
      final rawCover = primaryTrack.coverUrl;
      final isRemote = rawCover != null && (rawCover.startsWith('http://') || rawCover.startsWith('https://'));
      coverUrl = isRemote ? rawCover : null;
      localCoverPath = isRemote ? null : rawCover;
      if (coverUrl == null && localCoverPath == null && entry.coverPath != null) {
        localCoverPath = entry.coverPath;
      }
      addedAt = entry.addedAt;
    } else {
      final qi = queueItems[primary.index - downloadedItems.length - lovedEntries.length];
      primaryTrack = qi.track;
      id = 'q_${qi.id}';
      queueItem = qi;
      coverUrl = primaryTrack.coverUrl;
      final isRemote = coverUrl != null && (coverUrl.startsWith('http://') || coverUrl.startsWith('https://'));
      if (isRemote) { coverUrl = primaryTrack.coverUrl; localCoverPath = null; }
      else { localCoverPath = primaryTrack.coverUrl; coverUrl = null; }
      addedAt = qi.createdAt;
      source = LibraryItemSource.downloaded;
    }

    final qualityStr = [
      if (primaryTrack.audioQuality != null && primaryTrack.audioQuality!.isNotEmpty) primaryTrack.audioQuality!,
      if (primaryTrack.codec != null && primaryTrack.codec!.isNotEmpty) primaryTrack.codec!,
    ].join(' · ');

    // Build all non-primary sources as alternates with source info
    final alts = <Track>[];
    int idx = 0;

    for (final item in downloadedItems) {
      if (idx != primary.index || !primary.isDownloaded) {
        final t = item.toTrack();
        allTracks.add(SourceInfo(track: t, filePath: item.filePath, service: item.historyItem?.service, isrc: item.historyItem?.isrc));
        alts.add(t);
      }
      idx++;
    }
    for (final entry in lovedEntries) {
      if (idx != primary.index || !primary.isLoved) {
        allTracks.add(SourceInfo(track: entry.track));
        alts.add(entry.track);
      }
      idx++;
    }
    for (final qi in queueItems) {
      if (idx != primary.index || (primary.isDownloaded || primary.isLoved)) {
        allTracks.add(SourceInfo(track: qi.track));
        alts.add(qi.track);
      }
      idx++;
    }

    // Sort alternates by quality
    alts.sort((a, b) {
      final scoreA = _qualityScore(a);
      final scoreB = _qualityScore(b);
      return scoreB - scoreA;
    });

    return UnifiedLibraryItem(
      id: id,
      trackName: primaryTrack.name,
      artistName: primaryTrack.artistName,
      albumName: primaryTrack.albumName,
      coverUrl: coverUrl,
      localCoverPath: localCoverPath,
      filePath: filePath,
      quality: qualityStr,
      addedAt: addedAt,
      source: source,
      historyItem: historyItem,
      localItem: localItem,
      lovedEntry: lovedEntry,
      queueItem: queueItem,
      alternateSources: alts.isEmpty ? null : alts,
      alternateSourceInfo: allTracks.isEmpty ? null : allTracks,
    );
  }
}

class SourceInfo {
  final Track track;
  final String? filePath;
  final String? service;
  final String? isrc;

  const SourceInfo({
    required this.track,
    this.filePath,
    this.service,
    this.isrc,
  });
}
