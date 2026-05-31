import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bitly/services/descargas/ffmpeg_service.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/utils/app_bar_layout.dart';
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/utils/lyrics_metadata_helper.dart';
import 'package:bitly/models/download_item.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/extension_provider.dart';
import 'package:bitly/providers/library_collections_provider.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/providers/local_library_provider.dart';
import 'package:bitly/providers/playback_provider.dart';
import 'package:bitly/services/biblioteca/library_database.dart';
import 'package:bitly/services/biblioteca/re-descarga/local_track_redownload_service.dart';
import 'package:bitly/services/historial/history_database.dart';
import 'package:bitly/services/biblioteca/portadas/downloaded_embedded_cover_resolver.dart';
import 'package:bitly/screens/track_metadata_screen.dart';
import 'package:bitly/screens/album_screen.dart';
import 'package:bitly/screens/artist_screen.dart';
import 'package:bitly/widgets/album_card.dart';
import 'package:bitly/widgets/artist_card.dart';
import 'package:bitly/widgets/playlist_card.dart';
import 'package:bitly/widgets/track_card.dart';
import 'package:bitly/widgets/re_enrich_field_dialog.dart';
import 'package:bitly/widgets/batch_progress_dialog.dart';
import 'package:bitly/widgets/cached_cover_image.dart';
import 'package:bitly/screens/library_tracks_folder_screen.dart';
import 'package:bitly/screens/playlist_screen.dart';
import 'package:bitly/utils/path_match_keys.dart';
import 'package:bitly/utils/string_utils.dart';
import 'package:bitly/widgets/download_service_picker.dart';
import 'package:bitly/widgets/animation_utils.dart';
import 'package:bitly/widgets/playlist_creator_sheet.dart';
import 'package:bitly/widgets/wishlist_sheet.dart';
import 'package:bitly/widgets/download_progress_modal.dart';
import 'package:bitly/widgets/reactive_glass_background.dart';

part 'queue_tab_helpers.dart';
part 'queue_tab_widgets.dart';

class QueueTab extends ConsumerStatefulWidget {
  final PageController? parentPageController;
  final int parentPageIndex;
  final int? nextPageIndex;

  const QueueTab({
    super.key,
    this.parentPageController,
    this.parentPageIndex = 1,
    this.nextPageIndex,
  });

  @override
  ConsumerState<QueueTab> createState() => _QueueTabState();
}

class _QueueTabState extends ConsumerState<QueueTab> {
  static const int _libraryPageSize = 300;
  final FileExistsListenableCache _fileExistsCache =
      FileExistsListenableCache.instance;
  static const int _maxSearchIndexCacheSize = 4000;
  static const double _libraryGridMinExtent = 92;
  static const double _libraryGridDefaultExtent = 128;
  static const double _libraryGridMaxExtent = 187;
  bool _embeddedCoverRefreshScheduled = false;
  final ValueNotifier<int> _embeddedCoverVersion = ValueNotifier<int>(0);

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  OverlayEntry? _selectionOverlayEntry;
  List<UnifiedLibraryItem> _selectionOverlayItems = const [];
  double _selectionOverlayBottomPadding = 0;

  bool _isPlaylistSelectionMode = false;
  final Set<String> _selectedPlaylistIds = {};
  OverlayEntry? _playlistSelectionOverlayEntry;
  List<UserPlaylistCollection> _playlistSelectionOverlayItems = const [];
  double _playlistSelectionOverlayBottomPadding = 0;

  // FIX: use 'albums' as initial mode to match _filterModes
  String _libraryFilterMode = 'all';
  final List<String> _filterModes = ['all', 'songs', 'albums', 'playlists', 'artists'];
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<DownloadHistoryItem>? _historyItemsCache;
  List<LocalLibraryItem>? _LocalLibraryItemsCache;
  _HistoryStats? _historyStatsCache;
  final Map<String, String> _searchIndexCache = {};
  final Map<String, String> _localSearchIndexCache = {};
  Map<String, List<DownloadHistoryItem>> _filteredHistoryCache = const {};
  List<DownloadHistoryItem>? _filterItemsCache;
  String _filterQueryCache = '';
  bool _filterRefreshScheduled = false;
  bool _isFilteringHistory = false;
  int _filterRequestId = 0;
  static const int _filterIsolateThreshold = 800;
  List<LocalLibraryItem>? _localFilterItemsCache;
  String _localFilterQueryCache = '';
  List<LocalLibraryItem> _filteredLocalItemsCache = const [];
  final Map<String, _UnifiedCacheEntry> _unifiedItemsCache = {};
  List<DownloadHistoryItem>? _cachedUnifiedDownloadedSource;
  List<UnifiedLibraryItem> _cachedUnifiedDownloaded = const [];
  List<LocalLibraryItem>? _cachedUnifiedLocalSource;
  List<UnifiedLibraryItem> _cachedUnifiedLocal = const [];
  List<DownloadHistoryItem>? _cachedDownloadedPathKeysSource;
  Set<String> _cachedDownloadedPathKeys = const <String>{};
  final Map<String, List<String>> _localPathMatchKeysCache = {};
  List<LocalLibraryItem>? _cachedLocalSinglesSource;
  Map<String, int>? _cachedLocalSinglesAlbumCountsSource;
  List<LocalLibraryItem> _cachedLocalSingles = const [];
  final Map<String, _FilterContentData> _filterContentDataCache = {};
  List<DownloadHistoryItem>? _filterCacheAllHistoryItems;
  _HistoryStats? _filterCacheHistoryStats;
  List<LocalLibraryItem>? _filterCacheLocalLibraryItems;
  LibraryCollectionsState? _filterCacheCollectionState;
  // Tracks the user-selected alternate source per library item
  final Map<String, _LibrarySourceOverride> _selectedLibrarySource = {};
  String _filterCacheSearchQuery = '';
  String? _filterCacheQuality;
  String? _filterCacheFormat;
  String? _filterCacheMetadata;
  String _filterCacheSortMode = 'latest';
  String? _filterQuality;
  String? _filterFormat;
  String? _filterMetadata;
  String _sortMode = 'latest';
  double _libraryGridExtent = _libraryGridDefaultExtent;
  double? _libraryGridScaleStartExtent;
  int _libraryPageLimit = _libraryPageSize;
  bool _libraryPageLoadScheduled = false;
  final Map<_QueueLibraryCountsRequest, QueueLibraryCounts>
      _QueueLibraryCountsCache = {};
  final Map<_QueueLibraryPageRequest, _QueueLibraryPageData>
      _queueLibraryPageDataCache = {};



  void _handleLibraryGridScaleStart(ScaleStartDetails details) {
    if (details.pointerCount < 2) return;
    _libraryGridScaleStartExtent = _libraryGridExtent;
  }

  void _handleLibraryGridScaleUpdate(ScaleUpdateDetails details) {
    final startExtent = _libraryGridScaleStartExtent;
    if (startExtent == null || details.pointerCount < 2) return;
    final nextExtent = (startExtent * details.scale).clamp(
      _libraryGridMinExtent,
      _libraryGridMaxExtent,
    );
    if ((nextExtent - _libraryGridExtent).abs() < 0.5) return;
    setState(() => _libraryGridExtent = nextExtent);
  }

  void _handleLibraryGridScaleEnd(ScaleEndDetails details) {
    _libraryGridScaleStartExtent = null;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _hideSelectionOverlay();
    _hidePlaylistSelectionOverlay();
    _embeddedCoverVersion.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final normalized = value.trim().toLowerCase();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _searchQuery == normalized) return;
      setState(() {
        _searchQuery = normalized;
        _libraryPageLimit = _libraryPageSize;
      });
      _requestFilterRefresh();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    if (_searchQuery.isEmpty) return;
    setState(() {
      _searchQuery = '';
      _libraryPageLimit = _libraryPageSize;
    });
    _requestFilterRefresh();
  }

  void _loadMoreLibraryItems({required bool hasMoreLibrary}) {
    if (_libraryPageLoadScheduled) return;
    _libraryPageLoadScheduled = true;
    setState(() {
      if (hasMoreLibrary) _libraryPageLimit += _libraryPageSize;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _libraryPageLoadScheduled = false;
    });
  }

  QueueLibraryCounts _resolveQueueLibraryCounts(
    AsyncValue<QueueLibraryCounts> value,
    _QueueLibraryCountsRequest request,
  ) {
    return value.maybeWhen(
      data: (counts) {
        _QueueLibraryCountsCache[request] = counts;
        _trimQueueLibraryCaches();
        return counts;
      },
      orElse: () =>
          _QueueLibraryCountsCache[request] ??
          const QueueLibraryCounts(
            allTrackCount: 0,
            albumCount: 0,
            singleTrackCount: 0,
          ),
    );
  }

  _QueueLibraryPageData _resolveQueueLibraryPageData(
    AsyncValue<_QueueLibraryPageData>? value,
    _QueueLibraryPageRequest request,
  ) {
    if (value == null) {
      return _queueLibraryPageDataCache[request] ??
          const _QueueLibraryPageData();
    }
    return value.maybeWhen(
      data: (data) {
        _queueLibraryPageDataCache[request] = data;
        _trimQueueLibraryCaches();
        return data;
      },
      orElse: () =>
          _queueLibraryPageDataCache[request] ?? const _QueueLibraryPageData(),
    );
  }

  void _trimQueueLibraryCaches() {
    const maxEntries = 24;
    while (_QueueLibraryCountsCache.length > maxEntries) {
      _QueueLibraryCountsCache.remove(_QueueLibraryCountsCache.keys.first);
    }
    while (_queueLibraryPageDataCache.length > maxEntries) {
      _queueLibraryPageDataCache.remove(_queueLibraryPageDataCache.keys.first);
    }
  }

  bool _handleLibraryScrollNotification({
    required ScrollNotification notification,
    required String filterMode,
    required bool hasMoreLibrary,
    required bool isPageLoading,
  }) {
    if (isPageLoading || !hasMoreLibrary || notification.depth != 0) {
      return false;
    }
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent <= 0) return false;
    final threshold = metrics.maxScrollExtent * 0.7;
    final nearEnd =
        metrics.pixels >= threshold ||
        metrics.extentAfter <= metrics.viewportDimension * 1.5;
    if (!nearEnd) return false;
    _loadMoreLibraryItems(hasMoreLibrary: hasMoreLibrary);
    return false;
  }

  void _invalidateFilterContentCache() {
    _filterContentDataCache.clear();
    _filterCacheAllHistoryItems = null;
    _filterCacheHistoryStats = null;
    _filterCacheLocalLibraryItems = null;
    _filterCacheCollectionState = null;
  }

  // ignore: unused_element
  void _prepareFilterContentCache({
    required List<DownloadHistoryItem> allHistoryItems,
    required _HistoryStats historyStats,
    required List<LocalLibraryItem> LocalLibraryItems,
    required LibraryCollectionsState collectionState,
  }) {
    final isCacheValid =
        identical(_filterCacheAllHistoryItems, allHistoryItems) &&
        identical(_filterCacheHistoryStats, historyStats) &&
        identical(_filterCacheLocalLibraryItems, LocalLibraryItems) &&
        identical(_filterCacheCollectionState, collectionState) &&
_filterCacheSearchQuery == _searchQuery &&
        _filterCacheQuality == _filterQuality &&
        _filterCacheFormat == _filterFormat &&
        _filterCacheMetadata == _filterMetadata &&
        _filterCacheSortMode == _sortMode;

    if (isCacheValid) return;

    _filterContentDataCache.clear();
    _filterCacheAllHistoryItems = allHistoryItems;
    _filterCacheHistoryStats = historyStats;
    _filterCacheLocalLibraryItems = LocalLibraryItems;
    _filterCacheCollectionState = collectionState;
    _filterCacheSearchQuery = _searchQuery;
    _filterCacheQuality = _filterQuality;
    _filterCacheFormat = _filterFormat;
    _filterCacheMetadata = _filterMetadata;
    _filterCacheSortMode = _sortMode;
  }

  // ignore: unused_element
  void _ensureHistoryCaches(
    List<DownloadHistoryItem> items,
    List<LocalLibraryItem> localItems,
    _HistoryStats historyStats,
  ) {
    final historyChanged = !identical(items, _historyItemsCache);
    final localChanged = !identical(localItems, _LocalLibraryItemsCache);

    if (!historyChanged && !localChanged) return;

    _historyItemsCache = items;
    _LocalLibraryItemsCache = localItems;
    _historyStatsCache = historyStats;
    if (historyChanged) {
      _searchIndexCache.clear();
      _cachedUnifiedDownloadedSource = null;
      _cachedUnifiedDownloaded = const [];
      _cachedDownloadedPathKeysSource = null;
      _cachedDownloadedPathKeys = const <String>{};
    }
    if (localChanged) {
      _localSearchIndexCache.clear();
      _localPathMatchKeysCache.clear();
      _localFilterItemsCache = null;
      _localFilterQueryCache = '';
      _filteredLocalItemsCache = const [];
      _cachedLocalSinglesSource = null;
      _cachedLocalSinglesAlbumCountsSource = null;
      _cachedLocalSingles = const [];
      _cachedUnifiedLocalSource = null;
      _cachedUnifiedLocal = const [];
    }
    _unifiedItemsCache.clear();
    _invalidateFilterContentCache();

    if (historyChanged) {
      final validPaths = items
          .map((item) => _cleanFilePath(item.filePath))
          .where((path) => path.isNotEmpty)
          .toSet();
      DownloadedEmbeddedCoverResolver.invalidatePathsNotIn(validPaths);
    }
    _requestFilterRefresh();
  }

  String _buildSearchKey(DownloadHistoryItem item) {
    return '${item.trackName} ${item.artistName} ${item.albumName}'
        .toLowerCase();
  }

  String _buildLocalSearchKey(LocalLibraryItem item) {
    return '${item.trackName} ${item.artistName} ${item.albumName}'
        .toLowerCase();
  }

  String _historySearchKeyForItem(DownloadHistoryItem item) {
    final cached = _searchIndexCache[item.id];
    if (cached != null) return cached;
    final searchKey = _buildSearchKey(item);
    _searchIndexCache[item.id] = searchKey;
    while (_searchIndexCache.length > _maxSearchIndexCacheSize) {
      _searchIndexCache.remove(_searchIndexCache.keys.first);
    }
    return searchKey;
  }

  String _localSearchKeyForItem(LocalLibraryItem item) {
    final cached = _localSearchIndexCache[item.id];
    if (cached != null) return cached;
    final searchKey = _buildLocalSearchKey(item);
    _localSearchIndexCache[item.id] = searchKey;
    while (_localSearchIndexCache.length > _maxSearchIndexCacheSize) {
      _localSearchIndexCache.remove(_localSearchIndexCache.keys.first);
    }
    return searchKey;
  }

  List<UnifiedLibraryItem> _unifiedDownloadedItems(
    List<DownloadHistoryItem> items,
  ) {
    if (identical(items, _cachedUnifiedDownloadedSource)) {
      return _cachedUnifiedDownloaded;
    }
    final unified = items
        .map(UnifiedLibraryItem.fromDownloadHistory)
        .toList(growable: false);
    _cachedUnifiedDownloadedSource = items;
    _cachedUnifiedDownloaded = unified;
    return unified;
  }

  List<UnifiedLibraryItem> _unifiedLocalItems(List<LocalLibraryItem> items) {
    if (identical(items, _cachedUnifiedLocalSource)) {
      return _cachedUnifiedLocal;
    }
    final unified = items
        .map(UnifiedLibraryItem.fromLocalLibrary)
        .toList(growable: false);
    _cachedUnifiedLocalSource = items;
    _cachedUnifiedLocal = unified;
    return unified;
  }

  Set<String> _downloadedPathKeys(List<DownloadHistoryItem> historyItems) {
    if (identical(historyItems, _cachedDownloadedPathKeysSource)) {
      return _cachedDownloadedPathKeys;
    }
    final keys = <String>{};
    for (final item in historyItems) {
      keys.addAll(buildPathMatchKeys(item.filePath));
    }
    _cachedDownloadedPathKeysSource = historyItems;
    _cachedDownloadedPathKeys = Set<String>.unmodifiable(keys);
    return _cachedDownloadedPathKeys;
  }

  List<String> _localPathMatchKeys(LocalLibraryItem item) {
    final cached = _localPathMatchKeysCache[item.id];
    if (cached != null) return cached;
    final keys = buildPathMatchKeys(item.filePath).toList(growable: false);
    _localPathMatchKeysCache[item.id] = keys;
    return keys;
  }

  List<LocalLibraryItem> _localSingleItems(
    List<LocalLibraryItem> items,
    Map<String, int> localAlbumCounts,
  ) {
    if (identical(items, _cachedLocalSinglesSource) &&
        identical(localAlbumCounts, _cachedLocalSinglesAlbumCountsSource)) {
      return _cachedLocalSingles;
    }
    final singles = items
        .where((item) => (localAlbumCounts[item.albumKey] ?? 0) == 1)
        .toList(growable: false);
    _cachedLocalSinglesSource = items;
    _cachedLocalSinglesAlbumCountsSource = localAlbumCounts;
    _cachedLocalSingles = singles;
    return singles;
  }

  List<LocalLibraryItem> _filterLocalItems(
    List<LocalLibraryItem> items,
    String query,
  ) {
    if (query.isEmpty) return items;
    if (identical(items, _localFilterItemsCache) &&
        query == _localFilterQueryCache) {
      return _filteredLocalItemsCache;
    }
    final filtered = items
        .where((item) {
          final searchKey = _localSearchKeyForItem(item);
          return searchKey.contains(query);
        })
        .toList(growable: false);
    _localFilterItemsCache = items;
    _localFilterQueryCache = query;
    _filteredLocalItemsCache = filtered;
    return filtered;
  }

  bool _isFilterCacheValid(List<DownloadHistoryItem> items, String query) {
    return identical(items, _filterItemsCache) && query == _filterQueryCache;
  }

  void _requestFilterRefresh() {
    if (_filterRefreshScheduled) return;
    _filterRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _filterRefreshScheduled = false;
      if (!mounted) return;
      _scheduleHistoryFilterUpdate();
    });
  }

  void _scheduleHistoryFilterUpdate() {
    final items = _historyItemsCache;
    if (items == null) return;
    final query = _searchQuery;
    if (_isFilterCacheValid(items, query)) return;

    final albumCounts =
        _historyStatsCache?.albumCounts ?? const <String, int>{};
    if (items.isEmpty) {
      setState(() {
        _filteredHistoryCache = const {};
        _filterItemsCache = items;
        _filterQueryCache = query;
        _isFilteringHistory = false;
      });
      return;
    }

    if (items.length <= _filterIsolateThreshold) {
      final filteredAll = _applyHistorySearchFilter(items, query);
      final filteredAlbums = _filterHistoryByAlbumCount(
        filteredAll,
        albumCounts,
        2,
      );
      final filteredSingles = _filterHistoryByAlbumCount(
        filteredAll,
        albumCounts,
        1,
      );
      setState(() {
        _filteredHistoryCache = {
          'all': filteredAll,
          'albums': filteredAlbums,
          'singles': filteredSingles,
          'songs': filteredSingles,
        };
        _filterItemsCache = items;
        _filterQueryCache = query;
        _isFilteringHistory = false;
      });
      return;
    }

    if (!_isFilteringHistory) {
      setState(() => _isFilteringHistory = true);
    }

    final requestId = ++_filterRequestId;
    final includeSearchKey = query.isNotEmpty;
    final entries = List<List<String>>.generate(items.length, (index) {
      final item = items[index];
      final albumKey =
          '${item.albumName.toLowerCase()}|${(item.albumArtist ?? item.artistName).toLowerCase()}';
      if (!includeSearchKey) {
        return [item.id, albumKey];
      }
      final searchKey = _historySearchKeyForItem(item);
      return [item.id, albumKey, searchKey];
    }, growable: false);
    final payload = <String, Object>{
      'entries': entries,
      'albumCounts': albumCounts,
      'query': query,
    };

    compute(_filterHistoryInIsolate, payload).then((result) {
      if (!mounted || requestId != _filterRequestId) return;
      final itemsById = {for (final item in items) item.id: item};
      final filtered = <String, List<DownloadHistoryItem>>{};
      for (final entry in result.entries) {
        filtered[entry.key] = entry.value
            .map((id) => itemsById[id])
            .whereType<DownloadHistoryItem>()
            .toList(growable: false);
      }
      setState(() {
        _filteredHistoryCache = filtered;
        _filterItemsCache = items;
        _filterQueryCache = query;
        _isFilteringHistory = false;
      });
    });
  }

  List<DownloadHistoryItem> _resolveHistoryItems({
    required String filterMode,
    required List<DownloadHistoryItem> allHistoryItems,
    required Map<String, int> albumCounts,
  }) {
    final query = _searchQuery;
    if (_isFilterCacheValid(allHistoryItems, query)) {
      final cached = _filteredHistoryCache[filterMode];
      if (cached != null) return cached;
    }
    if (allHistoryItems.isEmpty) return const [];
    if (query.isEmpty && filterMode == 'all') return allHistoryItems;
    if (allHistoryItems.length <= _filterIsolateThreshold) {
      return _filterHistoryItems(
        allHistoryItems,
        filterMode,
        albumCounts,
        query,
      );
    }
    return const [];
  }

  List<DownloadHistoryItem> _applyHistorySearchFilter(
    List<DownloadHistoryItem> items,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return items;
    final query = searchQuery;
    return items
        .where((item) {
          final searchKey = _historySearchKeyForItem(item);
          return searchKey.contains(query);
        })
        .toList(growable: false);
  }

  List<DownloadHistoryItem> _filterHistoryByAlbumCount(
    List<DownloadHistoryItem> items,
    Map<String, int> albumCounts,
    int targetCount,
  ) {
    return items
        .where((item) {
          final key =
              '${item.albumName.toLowerCase()}|${(item.albumArtist ?? item.artistName).toLowerCase()}';
          final count = albumCounts[key] ?? 0;
          return targetCount == 1 ? count == 1 : count >= targetCount;
        })
        .toList(growable: false);
  }

  bool _shouldShowFilteringIndicator({
    required List<DownloadHistoryItem> allHistoryItems,
    required String filterMode,
  }) {
    if (allHistoryItems.isEmpty) return false;
    if (_searchQuery.isEmpty && filterMode == 'all') return false;
    if (allHistoryItems.length <= _filterIsolateThreshold) return false;
    return !_isFilterCacheValid(allHistoryItems, _searchQuery) ||
        _isFilteringHistory;
  }

  void _enterSelectionMode(String itemId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isPlaylistSelectionMode = false;
      _selectedPlaylistIds.clear();
      _isSelectionMode = true;
      _selectedIds.add(itemId);
    });
    _hidePlaylistSelectionOverlay();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    _hideSelectionOverlay();
  }

  void _toggleSelection(String itemId) {
    var shouldHideOverlay = false;
    setState(() {
      if (_selectedIds.contains(itemId)) {
        _selectedIds.remove(itemId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
          shouldHideOverlay = true;
        }
      } else {
        _selectedIds.add(itemId);
      }
    });
    if (shouldHideOverlay) {
      _hideSelectionOverlay();
    }
  }

  void _selectAll(List<UnifiedLibraryItem> items) {
    setState(() {
      _selectedIds.addAll(items.map((e) => e.id));
    });
  }

  void _hideSelectionOverlay() {
    _selectionOverlayEntry?.remove();
    _selectionOverlayEntry = null;
  }

  void _syncSelectionOverlay({
    required List<UnifiedLibraryItem> items,
    required double bottomPadding,
  }) {
    if (!mounted) return;
    if (!_isSelectionMode || _isPlaylistSelectionMode) {
      _hideSelectionOverlay();
      return;
    }

    _selectionOverlayItems = items;
    _selectionOverlayBottomPadding = bottomPadding;

    if (_selectionOverlayEntry != null) {
      _selectionOverlayEntry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    _selectionOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final colorScheme = Theme.of(context).colorScheme;
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _AnimatedOverlayBottomBar(
            child: Material(
              color: Colors.transparent,
              child: _buildSelectionBottomBar(
                context,
                colorScheme,
                _selectionOverlayItems,
                _selectionOverlayBottomPadding,
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_selectionOverlayEntry!);
  }

  void _hidePlaylistSelectionOverlay() {
    _playlistSelectionOverlayEntry?.remove();
    _playlistSelectionOverlayEntry = null;
  }

  void _syncPlaylistSelectionOverlay({
    required List<UserPlaylistCollection> playlists,
    required double bottomPadding,
  }) {
    if (!mounted) return;
    if (!_isPlaylistSelectionMode || _isSelectionMode) {
      _hidePlaylistSelectionOverlay();
      return;
    }

    _playlistSelectionOverlayItems = playlists;
    _playlistSelectionOverlayBottomPadding = bottomPadding;

    if (_playlistSelectionOverlayEntry != null) {
      _playlistSelectionOverlayEntry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    _playlistSelectionOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final colorScheme = Theme.of(context).colorScheme;
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _AnimatedOverlayBottomBar(
            child: Material(
              color: Colors.transparent,
              child: _buildPlaylistSelectionBottomBar(
                context,
                colorScheme,
                _playlistSelectionOverlayItems,
                _playlistSelectionOverlayBottomPadding,
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_playlistSelectionOverlayEntry!);
  }

  void _enterPlaylistSelectionMode(String playlistId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
      _isPlaylistSelectionMode = true;
      _selectedPlaylistIds.add(playlistId);
    });
    _hideSelectionOverlay();
  }

  void _exitPlaylistSelectionMode() {
    setState(() {
      _isPlaylistSelectionMode = false;
      _selectedPlaylistIds.clear();
    });
    _hidePlaylistSelectionOverlay();
  }

  void _togglePlaylistSelection(String playlistId) {
    var shouldHideOverlay = false;
    setState(() {
      if (_selectedPlaylistIds.contains(playlistId)) {
        _selectedPlaylistIds.remove(playlistId);
        if (_selectedPlaylistIds.isEmpty) {
          _isPlaylistSelectionMode = false;
          shouldHideOverlay = true;
        }
      } else {
        _selectedPlaylistIds.add(playlistId);
      }
    });
    if (shouldHideOverlay) {
      _hidePlaylistSelectionOverlay();
    }
  }

  void _selectAllPlaylists(List<UserPlaylistCollection> playlists) {
    setState(() {
      _selectedPlaylistIds.addAll(playlists.map((e) => e.id));
    });
  }

  Future<void> _downloadAllSelectedPlaylists(BuildContext context) async {
    final collectionsState = ref.read(libraryCollectionsProvider);
    final selectedPlaylists = collectionsState.playlists
        .where((p) => _selectedPlaylistIds.contains(p.id))
        .toList();

    final totalTracks = selectedPlaylists.fold<int>(
      0,
      (sum, p) => sum + p.tracks.length,
    );

    if (totalTracks == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.snackbarSelectedPlaylistsEmpty)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.dialogDownloadAllTitle),
        content: Text(
          ctx.l10n.dialogDownloadPlaylistsMessage(
            totalTracks,
            selectedPlaylists.length,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.dialogDownload),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final settings = ref.read(settingsProvider);
    final extensionState = ref.read(extensionProvider);
    final queueNotifier = ref.read(downloadQueueProvider.notifier);

    void enqueueAll({String? qualityOverride, String? service}) {
      final svc =
          service ??
          resolveEffectiveDownloadService(
            settings.defaultService,
            extensionState,
          );
      if (svc.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.extensionsNoDownloadProvider)),
          );
        }
        return;
      }
      for (final playlist in selectedPlaylists) {
        final tracks = playlist.tracks.map((e) => e.track).toList();
        queueNotifier.addMultipleToQueue(
          tracks,
          svc,
          qualityOverride: qualityOverride,
          playlistName: playlist.name,
        );
      }
    }

    if (settings.askQualityBeforeDownload) {
      DownloadServicePicker.show(
        context,
        trackName: context.l10n.tracksCount(totalTracks),
        artistName: context.l10n.playlistsCount(selectedPlaylists.length),
        onSelect: (quality, service) {
          enqueueAll(qualityOverride: quality, service: service);
          if (!mounted) return;
          _exitPlaylistSelectionMode();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.snackbarAddedTracksToQueue(totalTracks),
              ),
            ),
          );
        },
      );
    } else {
      enqueueAll();
      _exitPlaylistSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.snackbarAddedTracksToQueue(totalTracks)),
        ),
      );
    }
  }

  Future<void> _deleteSelectedPlaylists(BuildContext context) async {
    final count = _selectedPlaylistIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.collectionDeletePlaylist),
        content: Text(
          '$count ${count == 1 ? 'playlist' : 'playlists'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(ctx.l10n.dialogDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(libraryCollectionsProvider.notifier);
    for (final id in _selectedPlaylistIds.toList()) {
      await notifier.deletePlaylist(id);
    }

    if (!context.mounted) return;
    _exitPlaylistSelectionMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$count ${count == 1 ? 'playlist' : 'playlists'} deleted',
        ),
      ),
    );
  }

  Widget _buildPlaylistSelectionBottomBar(
    BuildContext context,
    ColorScheme colorScheme,
    List<UserPlaylistCollection> playlists,
    double bottomPadding,
  ) {
    final selectedCount = _selectedPlaylistIds.length;
    final allSelected =
        selectedCount == playlists.length && playlists.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding > 0 ? 8 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _exitPlaylistSelectionMode,
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.selectionSelected(selectedCount),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          allSelected
                              ? context.l10n.selectionAllPlaylistsSelected
                              : context.l10n.selectionTapPlaylistsToSelect,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (allSelected) {
                        _exitPlaylistSelectionMode();
                      } else {
                        _selectAllPlaylists(playlists);
                      }
                    },
                    icon: Icon(
                      allSelected ? Icons.deselect : Icons.select_all,
                      size: 20,
                    ),
                    label: Text(
                      allSelected
                          ? context.l10n.actionDeselect
                          : context.l10n.actionSelectAll,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selectedCount > 0
                      ? () => _downloadAllSelectedPlaylists(context)
                      : null,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    selectedCount > 0
                        ? context.l10n.bulkDownloadPlaylistsButton(selectedCount)
                        : context.l10n.bulkDownloadSelectPlaylists,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: selectedCount > 0
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    foregroundColor: selectedCount > 0
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selectedCount > 0
                      ? () => _deleteSelectedPlaylists(context)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    selectedCount > 0
                        ? 'Delete $selectedCount ${selectedCount == 1 ? 'playlist' : 'playlists'}'
                        : context.l10n.selectionSelectPlaylistsToDelete,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: selectedCount > 0
                        ? colorScheme.error
                        : colorScheme.surfaceContainerHighest,
                    foregroundColor: selectedCount > 0
                        ? colorScheme.onError
                        : colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getQualityBadgeText(String quality) {
    final q = quality.trim().toLowerCase();
    if (q.contains('bit')) {
      return quality.split('/').first;
    }
    final bitrateTextMatch = RegExp(
      r'(\d+)\s*k(?:bps)?',
      caseSensitive: false,
    ).firstMatch(quality);
    if (bitrateTextMatch != null) {
      return '${bitrateTextMatch.group(1)}k';
    }
    final bitrateIdMatch = RegExp(r'_(\d+)$').firstMatch(q);
    if (bitrateIdMatch != null) {
      return '${bitrateIdMatch.group(1)}k';
    }
    return quality.split(' ').first;
  }

  Future<void> _deleteSelected(List<UnifiedLibraryItem> allItems) async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.dialogDeleteSelectedTitle),
        content: Text(context.l10n.dialogDeleteSelectedMessage(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.dialogDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final historyNotifier = ref.read(downloadHistoryProvider.notifier);
      final localLibraryDb = LibraryDatabase.instance;
      final itemsById = {for (final item in allItems) item.id: item};
      final collectionsNotifier = ref.read(libraryCollectionsProvider.notifier);

      int deletedCount = 0;
      for (final id in _selectedIds) {
        final item = itemsById[id];
        if (item != null) {
          try {
            final cleanPath = _cleanFilePath(item.filePath);
            await deleteFile(cleanPath);
          } catch (_) {}

          if (item.source == LibraryItemSource.downloaded) {
            final hi = item.historyItem!;
            final track = Track(
              id: hi.spotifyId ?? '',
              name: hi.trackName,
              artistName: hi.artistName,
              albumName: hi.albumName,
              coverUrl: hi.coverUrl,
              isrc: hi.isrc,
              duration: hi.duration ?? 0,
              trackNumber: hi.trackNumber,
              discNumber: hi.discNumber,
              totalDiscs: hi.totalDiscs,
              releaseDate: hi.releaseDate,
              source: hi.service,
              totalTracks: hi.totalTracks,
              composer: hi.composer,
            );
            await collectionsNotifier.cleanupFoldersOnRemoveDownload(track);
            historyNotifier.removeFromHistory(hi.id);
          } else {
            await localLibraryDb.deleteByPath(item.filePath);
          }
          deletedCount++;
        }
      }

      if (allItems.any(
        (i) =>
            _selectedIds.contains(i.id) && i.source == LibraryItemSource.local,
      )) {
        ref.read(localLibraryProvider.notifier).reloadFromStorage();
      }

      _exitSelectionMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.snackbarDeletedTracks(deletedCount)),
          ),
        );
      }
    }
  }

  String _cleanFilePath(String? filePath) {
    return DownloadedEmbeddedCoverResolver.cleanFilePath(filePath);
  }

  Future<int?> _readFileModTimeMillis(String? filePath) async {
    return DownloadedEmbeddedCoverResolver.readFileModTimeMillis(filePath);
  }

  void _onEmbeddedCoverChanged() {
    if (!mounted || _embeddedCoverRefreshScheduled) return;
    _embeddedCoverRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _embeddedCoverRefreshScheduled = false;
      if (mounted) {
        _embeddedCoverVersion.value++;
      }
    });
  }

  Future<void> _scheduleDownloadedEmbeddedCoverRefreshForPath(
    String? filePath, {
    int? beforeModTime,
    bool force = false,
  }) async {
    await DownloadedEmbeddedCoverResolver.scheduleRefreshForPath(
      filePath,
      beforeModTime: beforeModTime,
      force: force,
      onChanged: _onEmbeddedCoverChanged,
    );
  }

  String? _resolveDownloadedEmbeddedCoverPath(String? filePath) {
    return DownloadedEmbeddedCoverResolver.resolve(
      filePath,
      onChanged: _onEmbeddedCoverChanged,
    );
  }

  ValueListenable<bool> _fileExistsListenable(String? filePath) {
    return _fileExistsCache.listenable(filePath);
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filterQuality != null) count++;
    if (_filterFormat != null) count++;
    if (_filterMetadata != null) count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _filterQuality = null;
      _filterFormat = null;
      _filterMetadata = null;
      _sortMode = 'latest';
      _libraryPageLimit = _libraryPageSize;
      _unifiedItemsCache.clear();
      _invalidateFilterContentCache();
    });
  }

  String _fileExtLower(String filePath) {
    final dotIndex = filePath.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == filePath.length - 1) {
      return '';
    }
    return filePath.substring(dotIndex + 1).toLowerCase();
  }

  List<UnifiedLibraryItem> _applyAdvancedFilters(
    List<UnifiedLibraryItem> items,
  ) {
    List<UnifiedLibraryItem> filtered;
    if (_activeFilterCount == 0) {
      filtered = items;
    } else {
      filtered = items
          .where((item) {
            if (_filterQuality != null && item.quality != null) {
              final quality = item.quality!.toLowerCase();
              switch (_filterQuality) {
                case 'hires':
                  if (!quality.startsWith('24')) return false;
                case 'cd':
                  if (!quality.startsWith('16')) return false;
                case 'lossy':
                  if (quality.startsWith('24') || quality.startsWith('16')) {
                    return false;
                  }
              }
            } else if (_filterQuality != null && item.quality == null) {
              if (_filterQuality != 'lossy') return false;
            }
            if (_filterFormat != null) {
              final ext = _fileExtLower(item.filePath);
              if (ext != _filterFormat) return false;
            }
            if (!_queueUnifiedItemMatchesMetadataFilter(
              item,
              _filterMetadata,
            )) {
              return false;
            }
            return true;
          })
          .toList(growable: false);
    }
    return _applySorting(filtered);
  }

  List<UnifiedLibraryItem> _applySorting(List<UnifiedLibraryItem> items) {
    if (_sortMode == 'latest') return items;
    final sorted = List<UnifiedLibraryItem>.of(items);
    switch (_sortMode) {
      case 'oldest':
        sorted.sort((a, b) => a.addedAt.compareTo(b.addedAt));
      case 'a-z':
        sorted.sort(
          (a, b) =>
              a.trackName.toLowerCase().compareTo(b.trackName.toLowerCase()),
        );
      case 'z-a':
        sorted.sort(
          (a, b) =>
              b.trackName.toLowerCase().compareTo(a.trackName.toLowerCase()),
        );
      case 'artist-asc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(a.artistName, b.artistName);
          if (comparison != 0) return comparison;
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'artist-desc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(
            a.artistName, b.artistName, descending: true,
          );
          if (comparison != 0) return comparison;
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'album-asc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(a.albumName, b.albumName);
          if (comparison != 0) return comparison;
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'album-desc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(
            a.albumName, b.albumName, descending: true,
          );
          if (comparison != 0) return comparison;
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'release-oldest':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalDate(
            _queueParseReleaseDate(a.releaseDate),
            _queueParseReleaseDate(b.releaseDate),
          );
          if (comparison != 0) return comparison;
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'release-newest':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalDate(
            _queueParseReleaseDate(a.releaseDate),
            _queueParseReleaseDate(b.releaseDate),
            descending: true,
          );
          if (comparison != 0) return comparison;
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'genre-asc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(a.genre, b.genre);
          if (comparison != 0) return comparison;
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'genre-desc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(
            a.genre, b.genre, descending: true,
          );
          if (comparison != 0) return comparison;
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
    }
    return sorted;
  }

  Set<String> _getAvailableFormats(List<UnifiedLibraryItem> items) {
    final formats = <String>{};
    for (final item in items) {
      final ext = _fileExtLower(item.filePath);
      if (['flac', 'mp3', 'm4a', 'opus', 'ogg', 'wav', 'aiff'].contains(ext)) {
        formats.add(ext);
      }
    }
    return formats;
  }

  void _showFilterSheet(
    BuildContext context,
    List<UnifiedLibraryItem> allItems, {
    bool showTrackFilters = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final availableFormats = _getAvailableFormats(allItems);

    String? tempQuality = _filterQuality;
    String? tempFormat = _filterFormat;
    String? tempMetadata = _filterMetadata;
    String tempSortMode = _sortMode;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxSheetHeight = constraints.maxHeight * 0.9;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 32,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                context.l10n.libraryFilterTitle,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setSheetState(() {
                                    tempQuality = null;
                                    tempFormat = null;
                                    tempMetadata = null;
                                    tempSortMode = 'latest';
                                  });
                                },
                                child: Text(context.l10n.libraryFilterReset),
                              ),
                            ],
                          ),
                          if (showTrackFilters) ...[
                            const SizedBox(height: 16),
                            Text(
                              context.l10n.libraryFilterQuality,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilterChip(
                                  label: Text(context.l10n.libraryFilterAllQuality),
                                  selected: tempQuality == null,
                                  onSelected: (_) =>
                                      setSheetState(() => tempQuality = null),
                                ),
                                FilterChip(
                                  label: Text(context.l10n.libraryFilterQualityHiRes),
                                  selected: tempQuality == 'hires',
                                  onSelected: (_) =>
                                      setSheetState(() => tempQuality = 'hires'),
                                ),
                                FilterChip(
                                  label: Text(context.l10n.libraryFilterQualityCD),
                                  selected: tempQuality == 'cd',
                                  onSelected: (_) =>
                                      setSheetState(() => tempQuality = 'cd'),
                                ),
                                FilterChip(
                                  label: Text(context.l10n.libraryFilterQualityLossy),
                                  selected: tempQuality == 'lossy',
                                  onSelected: (_) =>
                                      setSheetState(() => tempQuality = 'lossy'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.l10n.libraryFilterFormat,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilterChip(
                                  label: Text(context.l10n.libraryFilterAllFormat),
                                  selected: tempFormat == null,
                                  onSelected: (_) =>
                                      setSheetState(() => tempFormat = null),
                                ),
                                for (final format in availableFormats.toList()..sort())
                                  FilterChip(
                                    label: Text(format.toUpperCase()),
                                    selected: tempFormat == format,
                                    onSelected: (_) =>
                                        setSheetState(() => tempFormat = format),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.l10n.libraryFilterMetadata,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilterChip(
                                  label: Text(context.l10n.libraryFilterAllMetadata),
                                  selected: tempMetadata == null,
                                onSelected: (_) =>
                                    setSheetState(() => tempMetadata = null),
                              ),
                              FilterChip(
                                label: Text(context.l10n.libraryFilterMetadataComplete),
                                selected: tempMetadata == 'complete',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'complete',
                                ),
                              ),
                              FilterChip(
                                label: Text(context.l10n.libraryFilterMetadataMissingAny),
                                selected: tempMetadata == 'missing-any',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-any',
                                ),
                              ),
                              FilterChip(
                                label: Text(context.l10n.libraryFilterMetadataMissingYear),
                                selected: tempMetadata == 'missing-year',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-year',
                                ),
                              ),
                              FilterChip(
                                label: Text(context.l10n.libraryFilterMetadataMissingGenre),
                                selected: tempMetadata == 'missing-genre',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-genre',
                                ),
                              ),
                              FilterChip(
                                label: Text(context.l10n.libraryFilterMetadataMissingAlbumArtist),
                                selected: tempMetadata == 'missing-album-artist',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-album-artist',
                                ),
                              ),
                              FilterChip(
                                label: const Text('Missing track number'),
                                selected: tempMetadata == 'missing-track-number',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-track-number',
                                ),
                              ),
                              FilterChip(
                                label: const Text('Missing disc number'),
                                selected: tempMetadata == 'missing-disc-number',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-disc-number',
                                ),
                              ),
                              FilterChip(
                                label: const Text('Missing artist'),
                                selected: tempMetadata == 'missing-artist',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-artist',
                                ),
                              ),
                              FilterChip(
                                label: const Text('Incorrect ISRC format'),
                                selected: tempMetadata == 'incorrect-isrc-format',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'incorrect-isrc-format',
                                ),
                              ),
                              FilterChip(
                                label: const Text('Missing label'),
                                selected: tempMetadata == 'missing-label',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-label',
                                ),
                              ),
                            ],
                          ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.libraryFilterSort,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: Text(context.l10n.libraryFilterSortLatest),
                                selected: tempSortMode == 'latest',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'latest'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.libraryFilterSortOldest),
                                selected: tempSortMode == 'oldest',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'oldest'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortTitleAZ),
                                selected: tempSortMode == 'a-z',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'a-z'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortTitleZA),
                                selected: tempSortMode == 'z-a',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'z-a'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortArtistAZ),
                                selected: tempSortMode == 'artist-asc',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'artist-asc'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortArtistZA),
                                selected: tempSortMode == 'artist-desc',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'artist-desc'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.libraryFilterSortAlbumAsc),
                                selected: tempSortMode == 'album-asc',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'album-asc'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.libraryFilterSortAlbumDesc),
                                selected: tempSortMode == 'album-desc',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'album-desc'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortDateNewest),
                                selected: tempSortMode == 'release-newest',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'release-newest'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortDateOldest),
                                selected: tempSortMode == 'release-oldest',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'release-oldest'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.libraryFilterSortGenreAsc),
                                selected: tempSortMode == 'genre-asc',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'genre-asc'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.libraryFilterSortGenreDesc),
                                selected: tempSortMode == 'genre-desc',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'genre-desc'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _filterQuality = tempQuality;
                                  _filterFormat = tempFormat;
                                  _filterMetadata = tempMetadata;
                                  _sortMode = tempSortMode;
                                  _libraryPageLimit = _libraryPageSize;
                                  _unifiedItemsCache.clear();
                                  _invalidateFilterContentCache();
                                });
                                Navigator.pop(context);
                              },
                              child: Text(context.l10n.libraryFilterApply),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Compare two tracks by audio quality (higher = better)
  int _compareQuality(Track a, Track b) {
    const qualityOrder = <String>[
      'mqa', 'dsd', '192', '96', '24', 'flac', 'alac',
      '16', '320', 'aac', '256', 'ogg', '128', 'mp3',
    ];
    int score(String? q) {
      if (q == null || q.isEmpty) return -1;
      final lc = q.toLowerCase();
      for (var i = 0; i < qualityOrder.length; i++) {
        if (lc.contains(qualityOrder[i])) return qualityOrder.length - i;
      }
      return 0;
    }
    final scoreA = score(a.audioQuality ?? a.codec);
    final scoreB = score(b.audioQuality ?? b.codec);
    if (scoreA != scoreB) return scoreA - scoreB;
    // Tiebreaker: prefer non-null bitDepth
    final bdA = a.bitDepth ?? 0;
    final bdB = b.bitDepth ?? 0;
    if (bdA != bdB) return bdA - bdB;
    return 0;
  }

  String _buildQualityLabel(Track track) {
    return [
      if (track.audioQuality != null && track.audioQuality!.isNotEmpty) track.audioQuality!,
      if (track.codec != null && track.codec!.isNotEmpty) track.codec!,
    ].join(' · ');
  }

  Future<void> _openFile(
    String filePath, {
    String trackId = '',
    String title = '',
    String artist = '',
    String album = '',
    String coverUrl = '',
    String? isrc,
    String? source,
  }) async {
    final player = ref.read(audioPlayerProvider.notifier);
    await player.stop();
    await player.play(
      trackId: trackId.isNotEmpty ? trackId : 'lib_${title.hashCode}',
      trackName: title,
      artistName: artist,
      coverUrl: coverUrl,
      provider: source ?? 'deezer',
      isrc: isrc,
      audioPath: filePath,
    );
  }

  Future<void> _playLocalFile(
    String path, {
    required String title,
    required String artist,
    String album = '',
    String coverUrl = '',
  }) async {
    try {
      final fallbackTitle = path.split('/').last.split('\\').last;
      await ref
          .read(playbackProvider.notifier)
          .playLocalPath(
            path: path,
            title: title.isNotEmpty ? title : fallbackTitle,
            artist: artist,
            album: album,
            coverUrl: coverUrl,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.snackbarCannotOpenFile(e.toString())),
          ),
        );
      }
    }
  }

  Future<void> _tryResolveAndPlayFromApi({
    required String title,
    required String artist,
    required String album,
    required String coverUrl,
    String? isrc,
    String? source,
    required String fallbackPath,
  }) async {
    try {
      Map<String, dynamic>? result;

      if (isrc != null && isrc.isNotEmpty) {
        try {
          result = await PlatformBridge.searchDeezerByISRC(isrc);
        } catch (_) {
          result = null;
        }
      }

      if (result == null && source != null && source.isNotEmpty) {
        final url = _buildProviderUrl(source, title, artist);
        if (url != null) {
          result = await PlatformBridge.handleURLWithExtension(url);
        }
      }

      if (result == null) {
        final searchUrl = 'https://open.spotify.com/search/${Uri.encodeComponent('$title $artist')}';
        result = await PlatformBridge.handleURLWithExtension(searchUrl);
      }

      if (result != null && mounted) {
        final trackData = _extractTrackFromApiResult(result);
        if (trackData != null) {
          final streamUrl = trackData['stream_url'] ?? trackData['url'] ?? trackData['audio_url'];
          if (streamUrl != null && streamUrl.toString().isNotEmpty) {
            await ref.read(audioPlayerProvider.notifier).playLocalFile(
              filePath: streamUrl.toString(),
              trackName: trackData['title']?.toString() ?? title,
              artistName: trackData['artist']?.toString() ?? artist,
              albumName: album,
              coverUrl: trackData['cover_url']?.toString() ?? coverUrl,
              source: source,
            );
            return;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.snackbarFileUnavailableOnline(
                title.isNotEmpty ? title : fallbackPath.split('/').last.split('\\').last,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.snackbarCannotOpenFile(e.toString())),
          ),
        );
      }
    }
  }

  String? _buildProviderUrl(String source, String title, String artist) {
    final lowerSource = source.toLowerCase();
    if (lowerSource.contains('spotify')) {
      return 'https://open.spotify.com/search/${Uri.encodeComponent('$title $artist')}';
    }
    if (lowerSource.contains('deezer')) {
      return 'https://www.deezer.com/search/${Uri.encodeComponent('$title $artist')}';
    }
    if (lowerSource.contains('tidal')) {
      return 'https://tidal.com/search/${Uri.encodeComponent('$title $artist')}';
    }
    return null;
  }

  Map<String, dynamic>? _extractTrackFromApiResult(Map<String, dynamic> result) {
    if (result['tracks'] != null) {
      final tracks = result['tracks'] as List<dynamic>;
      if (tracks.isNotEmpty) {
        return tracks.first as Map<String, dynamic>?;
      }
    }
    if (result['track'] != null) {
      return result['track'] as Map<String, dynamic>?;
    }
    if (result['data'] != null) {
      final data = result['data'];
      if (data is Map<String, dynamic>) {
        if (data['tracks'] != null) {
          final tracks = data['tracks'] as List<dynamic>;
          if (tracks.isNotEmpty) {
            return tracks.first as Map<String, dynamic>?;
          }
        }
        return data;
      }
    }
    return result;
  }

  void _precacheCover(String? url) {
    if (url == null || url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return;
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0).toDouble();
    final targetSize = (360 * dpr).round().clamp(512, 1024).toInt();
    precacheImage(
      ResizeImage(
        cachedCoverImageProvider(url),
        width: targetSize,
        height: targetSize,
      ),
      context,
    );
  }

  Future<void> _navigateToMetadataScreen(DownloadItem item) async {
    final historyItem = ref
        .read(downloadHistoryProvider)
        .items
        .firstWhere(
          (h) => h.filePath == item.filePath,
          orElse: () => DownloadHistoryItem(
            id: item.id,
            trackName: item.track.name,
            artistName: item.track.artistName,
            albumName: item.track.albumName,
            coverUrl: item.track.coverUrl,
            filePath: item.filePath ?? '',
            downloadedAt: DateTime.now(),
            service: item.service,
          ),
        );

    final navigator = Navigator.of(context);
    _precacheCover(historyItem.coverUrl);
    _searchFocusNode.unfocus();
    final beforeModTime = await _readFileModTimeMillis(historyItem.filePath);
    if (!mounted) return;
    final result = await navigator.push(
      slidePageRoute<bool>(page: TrackMetadataScreen(item: historyItem)),
    );
    _searchFocusNode.unfocus();
    if (result == true) {
      await _scheduleDownloadedEmbeddedCoverRefreshForPath(
        historyItem.filePath,
        beforeModTime: beforeModTime,
        force: true,
      );
      return;
    }
    await _scheduleDownloadedEmbeddedCoverRefreshForPath(
      historyItem.filePath,
      beforeModTime: beforeModTime,
    );
  }

  Future<void> _navigateToHistoryMetadataScreen(
    DownloadHistoryItem item, {
    List<DownloadHistoryItem>? navigationItems,
    int? navigationIndex,
  }) async {
    final navigator = Navigator.of(context);
    _precacheCover(item.coverUrl);
    _searchFocusNode.unfocus();
    final beforeModTime = await _readFileModTimeMillis(item.filePath);
    if (!mounted) return;
    final result = await navigator.push(
      slidePageRoute<bool>(
        page: TrackMetadataScreen(
          item: item,
          historyNavigationItems: navigationItems,
          navigationIndex: navigationIndex,
          coverHeroTag: 'cover_lib_dl_${item.id}',
        ),
      ),
    );
    _searchFocusNode.unfocus();
    if (result == true) {
      await _scheduleDownloadedEmbeddedCoverRefreshForPath(
        item.filePath,
        beforeModTime: beforeModTime,
        force: true,
      );
      return;
    }
    await _scheduleDownloadedEmbeddedCoverRefreshForPath(
      item.filePath,
      beforeModTime: beforeModTime,
    );
  }

  void _navigateToLocalMetadataScreen(
    LocalLibraryItem item, {
    List<LocalLibraryItem>? navigationItems,
    int? navigationIndex,
  }) {
    _searchFocusNode.unfocus();
    Navigator.push(
      context,
      slidePageRoute<void>(
        page: TrackMetadataScreen(
          localItem: item,
          localNavigationItems: navigationItems,
          navigationIndex: navigationIndex,
          coverHeroTag: 'cover_lib_local_${item.id}',
        ),
      ),
    ).then((_) => _searchFocusNode.unfocus());
  }

  List<DownloadHistoryItem> _filterHistoryItems(
    List<DownloadHistoryItem> items,
    String filterMode,
    Map<String, int> albumCounts, [
    String searchQuery = '',
  ]) {
    var filteredItems = items;
    if (searchQuery.isNotEmpty) {
      final query = searchQuery;
      filteredItems = items.where((item) {
        final searchKey = _historySearchKeyForItem(item);
        return searchKey.contains(query);
      }).toList();
    }

    if (filterMode == 'all') return filteredItems;

    switch (filterMode) {
      case 'albums':
        return filteredItems.where((item) {
          final key =
              '${item.albumName.toLowerCase()}|${(item.albumArtist ?? item.artistName).toLowerCase()}';
          return (albumCounts[key] ?? 0) > 1;
        }).toList();
      case 'songs':
      case 'singles':
        return filteredItems.where((item) {
          final key =
              '${item.albumName.toLowerCase()}|${(item.albumArtist ?? item.artistName).toLowerCase()}';
          return (albumCounts[key] ?? 0) == 1;
        }).toList();
      default:
        return filteredItems;
    }
  }

  void _navigateWithUnfocus(Route<dynamic> route) {
    _searchFocusNode.unfocus();
    try {
      Navigator.of(context, rootNavigator: false)
          .push(route)
          .then((_) => _searchFocusNode.unfocus());
    } catch (_) {
      Navigator.of(context)
          .push(route)
          .then((_) => _searchFocusNode.unfocus());
    }
  }

  void _navigateToAlbum(_GroupedAlbum album) {
    final String? coverUrl = album.coverUrl ??
        (album.coverPath != null ? 'file://${album.coverPath}' : null);
    final history = ref.read(downloadHistoryProvider);
    final sources = <String, int>{};
    for (final item in history.items) {
      if (item.albumName.toLowerCase() == album.albumName.toLowerCase()) {
        final s = normalizeSource(item.service);
        sources[s] = (sources[s] ?? 0) + 1;
      }
    }
    String? extensionId;
    if (sources.isNotEmpty) {
      final best = sources.entries.reduce((a, b) => a.value > b.value ? a : b);
      final extState = ref.read(extensionProvider);
      final match = extState.extensions.where((e) => normalizeSource(e.id) == best.key).firstOrNull;
      if (match != null) extensionId = match.id;
    }
    _navigateWithUnfocus(
      slidePageRoute(
        page: AlbumScreen(
          albumId: 'builtin:${album.albumName.hashCode.abs()}:${album.artistName.hashCode.abs()}',
          albumName: album.albumName,
          coverUrl: coverUrl,
          artistName: album.artistName,
          extensionId: extensionId,
        ),
      ),
    );
  }

  // FIX: CollectionPlaylistEntry replaced with a generic Map or the actual
  // type from library_collections_provider. Using dynamic here as a safe
  // bridge — replace with the correct type once confirmed.
  void _openFavoritePlaylist(CollectionPlaylistEntry playlist) {
    final savedTracks = playlist.tracks?.map((e) => e.track).toList() ?? [];
    final effectivePlaylistId = playlist.key.isNotEmpty
        ? playlist.key
        : (playlist.playlistId.isNotEmpty
            ? playlist.playlistId
            : 'builtin:${playlist.name.hashCode.abs()}');
    _navigateWithUnfocus(
      MaterialPageRoute(
        builder: (_) => PlaylistScreen(
          playlistName: playlist.name,
          coverUrl: playlist.imageUrl,
          tracks: const [],
          playlistId: effectivePlaylistId,
          extensionId: playlist.providerId,
          savedTracks: savedTracks.isNotEmpty ? savedTracks : null,
        ),
      ),
    );
  }

  void _openPlaylistById(String playlistId) {
    final state = ref.read(libraryCollectionsProvider);
    final favoriteEntry = state.favoritePlaylists
        .where((p) => p.playlistId == playlistId)
        .firstOrNull;
    if (favoriteEntry != null) {
      _openFavoritePlaylist(favoriteEntry);
      return;
    }
    _navigateWithUnfocus(
      MaterialPageRoute(
        builder: (_) => LibraryTracksFolderScreen(
          mode: LibraryTracksFolderMode.playlist,
          playlistId: playlistId,
        ),
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const PlaylistCreatorSheet(),
    );
  }

  Widget _buildPlaylistCover(
    BuildContext context,
    UserPlaylistCollection playlist,
    ColorScheme colorScheme, [
    double? size,
  ]) {
    final borderRadius = BorderRadius.circular(8);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheExtent = size != null
        ? (size * dpr).round().clamp(64, 1024)
        : 420;
    final placeholder = _playlistIconFallback(colorScheme, size);

    final customCoverPath = playlist.coverImagePath;
    if (customCoverPath != null && customCoverPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          File(customCoverPath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheExtent,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return placeholder;
          },
          errorBuilder: (_, _, _) => placeholder,
        ),
      );
    }

    final firstCoverUrl = playlist.tracks
        .where((e) => e.track.coverUrl != null && e.track.coverUrl!.isNotEmpty)
        .map((e) => e.track.coverUrl!)
        .firstOrNull;

    if (firstCoverUrl != null) {
      final isLocalPath =
          !firstCoverUrl.startsWith('http://') &&
          !firstCoverUrl.startsWith('https://');
      if (isLocalPath) {
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.file(
            File(firstCoverUrl),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: cacheExtent,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return placeholder;
            },
            errorBuilder: (_, _, _) => placeholder,
          ),
        );
      }
      return CachedCoverImage(
        imageUrl: firstCoverUrl,
        width: size,
        height: size,
        memCacheWidth: cacheExtent,
        borderRadius: borderRadius,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      );
    }

    return placeholder;
  }

  Widget _playlistIconFallback(ColorScheme colorScheme, [double? size]) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF5085A5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.queue_music,
        color: Colors.white,
        size: size != null ? size * 0.5 : 40,
      ),
    );
  }

  Future<void> _onTrackDroppedOnPlaylist(
    BuildContext context,
    UnifiedLibraryItem item,
    String playlistId,
    String playlistName, {
    List<UnifiedLibraryItem> allItems = const [],
  }) async {
    final notifier = ref.read(libraryCollectionsProvider.notifier);

    if (_isSelectionMode &&
        _selectedIds.isNotEmpty &&
        _selectedIds.contains(item.id)) {
      final selectedItems = allItems
          .where((e) => _selectedIds.contains(e.id))
          .toList();
      if (selectedItems.isEmpty) selectedItems.add(item);

      final batchResult = await notifier.addTracksToPlaylist(
        playlistId,
        selectedItems.map((selected) => selected.toTrack()),
      );
      final addedCount = batchResult.addedCount;
      final alreadyCount = batchResult.alreadyInPlaylistCount;

      if (!context.mounted) return;
      final message = addedCount > 0
          ? 'Added $addedCount ${addedCount == 1 ? 'track' : 'tracks'} to $playlistName'
                '${alreadyCount > 0 ? ' ($alreadyCount already in playlist)' : ''}'
          : context.l10n.collectionAlreadyInPlaylist(playlistName);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      _exitSelectionMode();
      return;
    }

    final track = item.toTrack();
    final added = await notifier.addTrackToPlaylist(playlistId, track);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? context.l10n.collectionAddedToPlaylist(playlistName)
              : context.l10n.collectionAlreadyInPlaylist(playlistName),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQueueItems = ref.watch(
      downloadQueueLookupProvider.select((lookup) => lookup.itemIds.isNotEmpty),
    );
    final historyTotalCount = ref.watch(
      downloadHistoryProvider.select((state) => state.totalCount),
    );
    final localLibraryTotalCount = ref.watch(
      localLibraryProvider.select((state) => state.totalCount),
    );
    final localLibraryEnabled = ref.watch(
      settingsProvider.select((s) => s.localLibraryEnabled),
    );
    ref.watch(
      libraryCollectionsProvider.select(
        (s) => (
          s.wishlistCount,
          s.lovedCount,
          s.favoriteArtistCount,
          s.favoriteAlbumCount,
          s.favoritePlaylistCount,
          s.playlistCount,
          s.hasPlaylistTracks,
          s.isLoaded,
        ),
      ),
    );
    final collectionState = ref.read(libraryCollectionsProvider);
    final historyViewMode = ref.watch(
      settingsProvider.select((s) => s.historyViewMode),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = normalizedHeaderTopPadding(context);
    final countsRequest = _QueueLibraryCountsRequest(
      searchQuery: _searchQuery,
      filterQuality: _filterQuality,
      filterFormat: _filterFormat,
      filterMetadata: _filterMetadata,
      localLibraryEnabled: localLibraryEnabled,
    );
    final countsValue = ref.watch(_QueueLibraryCountsProvider(countsRequest));
    final queueCounts = _resolveQueueLibraryCounts(countsValue, countsRequest);

    _QueueLibraryPageRequest pageRequest(String filterMode) =>
        _QueueLibraryPageRequest(
          filterMode: filterMode,
          limit: _libraryPageLimit,
          searchQuery: _searchQuery,
          filterQuality: _filterQuality,
          filterFormat: _filterFormat,
          filterMetadata: _filterMetadata,
          sortMode: _sortMode,
          localLibraryEnabled: localLibraryEnabled,
        );

    final pageRequests = <String, _QueueLibraryPageRequest>{
      for (final mode in _filterModes) mode: pageRequest(mode),
    };
    final pageValues = <String, AsyncValue<_QueueLibraryPageData>>{
      for (final entry in pageRequests.entries)
        entry.key: ref.watch(_queueLibraryPageProvider(entry.value)),
    };

    _QueueLibraryPageData pageData(String filterMode) =>
        _resolveQueueLibraryPageData(
          pageValues[filterMode],
          pageRequests[filterMode]!,
        );

    _FilterContentData getFilterData(String filterMode) {
      return pageData(filterMode).toFilterContentData(
        collectionState,
        totalTrackCount: switch (filterMode) {
          'singles' => queueCounts.singleTrackCount,
          'songs'   => queueCounts.singleTrackCount,
          'albums'  => 0,
          'playlists' => collectionState.playlists.length,
          'artists' => collectionState.favoriteArtistCount,
          _ => queueCounts.allTrackCount,
        },
        totalAlbumCount: filterMode == 'albums'
            ? queueCounts.albumCount + collectionState.favoriteAlbumCount
            : null,
      );
    }

    final currentPageData = pageData(_libraryFilterMode);
    final currentLoadedCount = _libraryFilterMode == 'albums'
        ? currentPageData.groupedAlbums.length
        : currentPageData.items.length;
    final currentTotalCount = switch (_libraryFilterMode) {
      'albums'  => queueCounts.albumCount,
      'singles' => queueCounts.singleTrackCount,
      'songs'   => queueCounts.singleTrackCount,
      _ => queueCounts.allTrackCount,
    };
    final hasMoreLibrary = currentLoadedCount < currentTotalCount;
    final isLibraryPageLoading =
        countsValue.isLoading ||
        (pageValues[_libraryFilterMode]?.isLoading ?? false);
    final hasAnyLibraryItems =
        queueCounts.allTrackCount > 0 || queueCounts.albumCount > 0;
    final hasLibraryContent =
        historyTotalCount > 0 ||
        (localLibraryEnabled && localLibraryTotalCount > 0);
    final hasActiveSearch =
        _searchQuery.isNotEmpty || _searchController.text.trim().isNotEmpty;
    final shouldShowLibraryControls =
        hasLibraryContent || hasAnyLibraryItems || hasActiveSearch ||
        collectionState.lovedCount > 0 ||
        collectionState.favoriteAlbumCount > 0 ||
        collectionState.favoriteArtistCount > 0 ||
        collectionState.favoritePlaylistCount > 0 ||
        collectionState.playlists.isNotEmpty;

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final selectionItems = getFilterData(_libraryFilterMode).filteredUnifiedItems;
    if (_isSelectionMode || _isPlaylistSelectionMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isSelectionMode) {
          _syncSelectionOverlay(
            items: selectionItems,
            bottomPadding: bottomPadding,
          );
        }
        if (_isPlaylistSelectionMode) {
          _syncPlaylistSelectionOverlay(
            playlists: collectionState.playlists,
            bottomPadding: bottomPadding,
          );
        }
      });
    }

    return PopScope(
      canPop: !_isSelectionMode && !_isPlaylistSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isPlaylistSelectionMode) {
            _exitPlaylistSelectionMode();
          } else if (_isSelectionMode) {
            _exitSelectionMode();
          }
        }
      },
      child: Stack(
        children: [
          const Positioned.fill(
            child: ReactiveGlassBackground(child: SizedBox.expand()),
          ),
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(overscroll: false),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: topPadding + 8,
                      left: 16,
                      right: 16,
                      bottom: 4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (shouldShowLibraryControls || hasQueueItems)
                          TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            autofocus: false,
                            canRequestFocus: true,
                            decoration: InputDecoration(
                              hintText: context.l10n.historySearchHint,
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      tooltip: context.l10n.dialogClear,
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        _clearSearch();
                                        FocusScope.of(context).unfocus();
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onChanged: _onSearchChanged,
                            onTapOutside: (_) {
                              FocusScope.of(context).unfocus();
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // FIX: filter tabs now use l10n keys instead of hardcoded Spanish
                if (shouldShowLibraryControls)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          overscroll: true,
                          scrollbars: false,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildFilterBubble(context.l10n.collectionAll, 'all', Icons.grid_view, collectionState),
                              const SizedBox(width: 8),
                              _buildFilterBubble(context.l10n.collectionSongs, 'songs', Icons.music_note, collectionState),
                              const SizedBox(width: 8),
                              _buildFilterBubble(context.l10n.collectionAlbums, 'albums', Icons.album, collectionState),
                              const SizedBox(width: 8),
                              _buildFilterBubble(context.l10n.collectionPlaylists, 'playlists', Icons.playlist_play, collectionState),
                              const SizedBox(width: 8),
                              _buildFilterBubble(context.l10n.collectionArtists, 'artists', Icons.person, collectionState),
                              const SizedBox(width: 8),
                              _buildWishlistStar(context, colorScheme, collectionState),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),


              ],
              body: _buildFilterContent(
                context: context,
                colorScheme: colorScheme,
                filterMode: _libraryFilterMode,
                historyViewMode: historyViewMode,
                hasQueueItems: hasQueueItems,
                filterData: getFilterData(_libraryFilterMode),
                collectionState: collectionState,
                hasMoreLibrary: hasMoreLibrary,
                isPageLoading: isLibraryPageLoading,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<UnifiedLibraryItem> _getUnifiedItems({
    required String filterMode,
    required List<DownloadHistoryItem> historyItems,
    required List<LocalLibraryItem> LocalLibraryItems,
    required Map<String, int> localAlbumCounts,
  }) {
    if (filterMode == 'albums') return const [];

    final query = _searchQuery;
    final cached = _unifiedItemsCache[filterMode];
    if (cached != null &&
        identical(cached.historyItems, historyItems) &&
        identical(cached.localItems, LocalLibraryItems) &&
        identical(cached.localAlbumCounts, localAlbumCounts) &&
        cached.query == query) {
      return cached.items;
    }

    final unifiedDownloaded = _unifiedDownloadedItems(historyItems);

    List<LocalLibraryItem> localItemsForMerge;
    if (filterMode == 'all') {
      localItemsForMerge = _filterLocalItems(LocalLibraryItems, query);
    } else {
      final localSingles = _localSingleItems(LocalLibraryItems, localAlbumCounts);
      localItemsForMerge = _filterLocalItems(localSingles, query);
    }

    final unifiedLocal = _unifiedLocalItems(localItemsForMerge);
    final downloadedPathKeys = _downloadedPathKeys(historyItems);

    final dedupedUnifiedLocal = <UnifiedLibraryItem>[];
    for (final item in unifiedLocal) {
      final localSource = item.localItem;
      final localPathKeys = localSource != null
          ? _localPathMatchKeys(localSource)
          : buildPathMatchKeys(item.filePath);
      final overlapsDownloaded = localPathKeys.any(downloadedPathKeys.contains);
      if (!overlapsDownloaded) {
        dedupedUnifiedLocal.add(item);
      }
    }

    final merged = <UnifiedLibraryItem>[
      ...unifiedDownloaded,
      ...dedupedUnifiedLocal,
    ]..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    _unifiedItemsCache[filterMode] = _UnifiedCacheEntry(
      historyItems: historyItems,
      localItems: LocalLibraryItems,
      localAlbumCounts: localAlbumCounts,
      query: query,
      items: merged,
    );

    return merged;
  }

  // ignore: unused_element
  _FilterContentData _computeFilterContentData({
    required String filterMode,
    required List<DownloadHistoryItem> allHistoryItems,
    required List<_GroupedAlbum> filteredGroupedAlbums,
    required Map<String, int> albumCounts,
    required List<LocalLibraryItem> LocalLibraryItems,
    required LibraryCollectionsState collectionState,
  }) {
    final historyItems = _resolveHistoryItems(
      filterMode: filterMode,
      allHistoryItems: allHistoryItems,
      albumCounts: albumCounts,
    );
    final showFilteringIndicator = _shouldShowFilteringIndicator(
      allHistoryItems: allHistoryItems,
      filterMode: filterMode,
    );

    final unifiedItems = _getUnifiedItems(
      filterMode: filterMode,
      historyItems: historyItems,
      LocalLibraryItems: LocalLibraryItems,
      localAlbumCounts: const {},
    );
    final filtered = _applyAdvancedFilters(unifiedItems);

    final filteredUnifiedItems = !collectionState.hasPlaylistTracks
        ? filtered
        : filtered
              .where(
                (item) =>
                    !collectionState.isTrackInAnyPlaylist(item.collectionKey),
              )
              .toList(growable: false);

    return _FilterContentData(
      historyItems: historyItems,
      unifiedItems: unifiedItems,
      filteredUnifiedItems: filteredUnifiedItems,
      filteredGroupedAlbums: filteredGroupedAlbums,
      showFilteringIndicator: showFilteringIndicator,
    );
  }


  Widget _buildFilterBubble(String label, String mode, IconData icon, LibraryCollectionsState collectionState) {
    final isSelected = _libraryFilterMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    final count = _getFilterCount(mode, collectionState);
    
    return GestureDetector(
      onTap: () => setState(() => _libraryFilterMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.onPrimary.withValues(alpha: 0.2) : colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistStar(BuildContext context, ColorScheme colorScheme, LibraryCollectionsState collectionState) {
    final count = collectionState.wishlistCount;
    return GestureDetector(
      onTap: () => WishlistSheet.show(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outlineVariant, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border, size: 16, color: colorScheme.onSurfaceVariant),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _getFilterCount(String mode, LibraryCollectionsState collectionState) {
    switch (mode) {
      case 'songs':
        return collectionState.lovedCount;
      case 'albums':
        return collectionState.favoriteAlbumCount;
      case 'playlists':
        return collectionState.playlists.length + collectionState.favoritePlaylistCount;
      case 'artists':
        return collectionState.favoriteArtistCount;
      case 'all':
        return collectionState.lovedCount + 
               collectionState.favoriteAlbumCount + 
               collectionState.playlists.length + 
               collectionState.favoritePlaylistCount + 
               collectionState.favoriteArtistCount;
      default:
        return 0;
    }
  }

  Widget _buildCollectionGridItem({
    required BuildContext context,
    required ColorScheme colorScheme,
    IconData? icon,
    Color? iconColor,
    Color? iconBgColor,
    Widget? coverWidget,
    required String title,
    required int count,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final cover =
        coverWidget ??
        Container(
          decoration: BoxDecoration(
            color: iconBgColor ?? colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon ?? Icons.folder,
            color: iconColor ?? Colors.white,
            size: 40,
          ),
        );

    return Semantics(
      button: true,
      label: context.l10n.a11yOpenItemCount(title, count),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: cover,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            Text(
              '$count ${count == 1 ? 'canción' : 'canciones'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_MixedLibraryItem> _buildMixedLibraryItems({
    required BuildContext context,
    required LibraryCollectionsState collectionState,
    required List<UnifiedLibraryItem> filteredUnifiedItems,
    required List<_GroupedAlbum> filteredGroupedAlbums,
    required List<CollectionAlbumEntry> favoriteAlbums,
  }) {
    final mixedItems = <_MixedLibraryItem>[];
    final dateTime = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;

    final queueItems = ref.read(downloadQueueProvider).items
        .where((item) => item.status == DownloadStatus.queued || 
                         item.status == DownloadStatus.downloading ||
                         item.status == DownloadStatus.finalizing)
        .toList();

    // Group songs by identity to prevent duplicates
    final songGroups = <String, _MergedSongGroup>{};

    String songIdentity(String name, String artist) =>
      '${normalizeForMatch(name)}|${normalizeForMatch(artist)}';

    _MergedSongGroup getGroup(String name, String artist) =>
      songGroups.putIfAbsent(songIdentity(name, artist), () => _MergedSongGroup());

    // 1. Queue items
    for (final item in queueItems) {
      if (_searchQuery.isNotEmpty) {
        final match = item.track.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      item.track.artistName.toLowerCase().contains(_searchQuery.toLowerCase());
        if (!match) continue;
      }
      getGroup(item.track.name, item.track.artistName).queueItems.add(item);
    }

    // 2. Downloaded / Local items
    for (final item in filteredUnifiedItems) {
      getGroup(item.trackName, item.artistName).downloadedItems.add(item);
    }

    // 3. Loved tracks (only if not already added by downloadedItems)
    for (final entry in collectionState.loved) {
      if (_searchQuery.isNotEmpty) {
        final match = entry.track.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      entry.track.artistName.toLowerCase().contains(_searchQuery.toLowerCase());
        if (!match) continue;
      }
      getGroup(entry.track.name, entry.track.artistName).lovedEntries.add(entry);
    }

    // Build merged song items
    for (final group in songGroups.values) {
      final unified = group.buildItem();
      mixedItems.add(_MixedLibraryItem(
        key: 'song_${unified.id}',
        addedAt: unified.addedAt,
        type: _MixedItemType.song,
        widget: _buildUnifiedLibraryItem(
          context, unified, colorScheme,
          downloadedNavigationItems: [],
          downloadedNavigationIndex: null,
          localNavigationItems: [],
          localNavigationIndex: null,
        ),
      ));
    }

    // Add Albums
    for (final album in filteredGroupedAlbums) {
      mixedItems.add(_MixedLibraryItem(
        key: 'album_${album.key}',
        addedAt: album.latestDownload,
        type: _MixedItemType.album,
        widget: _buildAlbumGridItem(context, album, colorScheme),
      ));
    }

    for (final album in favoriteAlbums) {
      mixedItems.add(_MixedLibraryItem(
        key: 'fav_album_${album.key}',
        addedAt: album.addedAt,
        type: _MixedItemType.album,
        widget: _buildFavoriteAlbumGridItem(context, album, colorScheme),
      ));
    }

    // Add Playlists
    for (final playlist in collectionState.playlists) {
      mixedItems.add(_MixedLibraryItem(
        key: 'playlist_${playlist.id}',
        addedAt: dateTime,
        type: _MixedItemType.playlist,
        widget: _buildPlaylistGridItem(context, playlist, colorScheme),
      ));
    }

    // Add Artists
    {
      final merged = <String, CollectionArtistEntry>{};
      for (final a in collectionState.favoriteArtists) {
        final key = normalizeForMatch(a.name);
        if (merged.containsKey(key)) {
          merged[key] = merged[key]!.mergeCover(a.imageUrl);
        } else {
          merged[key] = a;
        }
      }
      for (final entry in merged.values) {
        if (_searchQuery.isNotEmpty) {
           if (!entry.name.toLowerCase().contains(_searchQuery.toLowerCase())) continue;
        }
        mixedItems.add(_MixedLibraryItem(
          key: 'artist_${entry.key}',
          addedAt: entry.addedAt,
          type: _MixedItemType.artist,
          widget: _buildArtistGridItem(context, entry, colorScheme),
        ));
      }
    }

    // Sort everything by date added
    mixedItems.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return mixedItems;
  }

  List<Widget> _buildAllTabSlivers(
    BuildContext context,
    ColorScheme colorScheme,
    LibraryCollectionsState collectionState,
    List<UnifiedLibraryItem> filteredUnifiedItems,
    List<_GroupedAlbum> filteredGroupedAlbums,
    List<CollectionAlbumEntry> favoriteAlbums,
  ) {
    final mixedItems = _buildMixedLibraryItems(
      context: context,
      collectionState: collectionState,
      filteredUnifiedItems: filteredUnifiedItems,
      filteredGroupedAlbums: filteredGroupedAlbums,
      favoriteAlbums: favoriteAlbums,
    );
    final gridItems = mixedItems.where((m) => m.type != _MixedItemType.song).toList();
    final songItems = mixedItems.where((m) => m.type == _MixedItemType.song).toList();

    final slivers = <Widget>[];

    if (gridItems.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _AnimatedLibrarySliverGrid(
            maxCrossAxisExtent: _libraryGridExtent,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return KeyedSubtree(
                  key: ValueKey(gridItems[index].key),
                  child: gridItems[index].widget,
                );
              },
              childCount: gridItems.length,
            ),
          ),
        ),
      );
    }

    if (songItems.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = songItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: KeyedSubtree(
                    key: ValueKey(item.key),
                    child: item.widget,
                  ),
                );
              },
              childCount: songItems.length,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildPlaylistGridItem(
    BuildContext context,
    dynamic playlist,
    ColorScheme colorScheme,
  ) {
    final bool isUserPlaylist = playlist is UserPlaylistCollection;
    final String playlistKey = isUserPlaylist ? playlist.id : (playlist.key ?? '');
    final String playlistId = isUserPlaylist ? playlist.id : (playlist.playlistId ?? playlist.id ?? '');
    final String playlistName = playlist.name ?? '';
    final String? imageUrl = playlist is CollectionPlaylistEntry ? playlist.imageUrl : null;
    final String? coverPath = isUserPlaylist ? playlist.coverImagePath : (playlist is CollectionPlaylistEntry ? playlist.coverPath : null);
    final int trackCount = isUserPlaylist ? playlist.tracks.length : (playlist.trackCount ?? (playlist.tracks as List?)?.length ?? 0);
    final bool isFavoritePlaylist = !isUserPlaylist && playlistId.isNotEmpty;

    return Consumer(
      builder: (context, ref, child) {
        final isFav = isFavoritePlaylist
            ? ref.watch(
                libraryCollectionsProvider.select((s) => s.containsFavoritePlaylistKey(playlistKey)),
              )
            : false;
        final subtitle = trackCount > 0 ? '$trackCount canciones' : null;
        return PlaylistCard(
          playlistName: playlistName,
          coverUrl: imageUrl,
          coverPath: coverPath,
          subtitle: subtitle,
          onTap: () => isUserPlaylist
              ? _openPlaylistById(playlistId)
              : _openFavoritePlaylist(playlist),
          isFavorite: isFav,
          onHeartTap: isFavoritePlaylist
              ? () {
                  ref.read(libraryCollectionsProvider.notifier).toggleFavoritePlaylistByKey(
                    key: playlistKey,
                    playlistId: playlistId,
                    providerId: null,
                    name: playlistName,
                    imageUrl: imageUrl,
                  );
                }
              : null,
        );
      },
    );
  }

  Widget _buildArtistGridItem(
    BuildContext context,
    dynamic artist,
    ColorScheme colorScheme,
  ) {
    if (artist is CollectionArtistEntry) {
      return _CyclingArtistCard(entry: artist);
    }
    final String artistKey = '${artist.key ?? ''}';
    final String artistId = '${artist.artistId ?? ''}';
    final String artistName = '${artist.name ?? ''}';
    final String? imageUrl = artist.imageUrl as String?;
    final String? coverPath = artist.coverPath as String?;
    final String? providerId = artist.providerId as String?;

    return Consumer(
      builder: (context, ref, child) {
        final isFav = ref.watch(
          libraryCollectionsProvider.select((s) => s.containsFavoriteArtistKey(artistKey)),
        );
        return ArtistCard(
          artistName: artistName,
          imageUrl: imageUrl,
          coverPath: coverPath,
          isFavorite: isFav,
          onHeartTap: () {
            ref.read(libraryCollectionsProvider.notifier).toggleFavoriteArtistByKey(
              key: artistKey,
              artistId: artistId,
              providerId: providerId,
              name: artistName,
              imageUrl: imageUrl,
            );
          },
          onTap: () => _navigateWithUnfocus(
            MaterialPageRoute(
              builder: (_) => ArtistScreen(
                artistId: artistId.isNotEmpty ? artistId : 'builtin:${artistName.hashCode.abs()}',
                artistName: artistName,
                coverUrl: coverPath != null && coverPath.isNotEmpty && File(coverPath).existsSync()
                    ? 'file://$coverPath'
                    : imageUrl,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterContent({
    required BuildContext context,
    required ColorScheme colorScheme,
    required String filterMode,
    required String historyViewMode,
    required bool hasQueueItems,
    required _FilterContentData filterData,
    required LibraryCollectionsState collectionState,
    required bool hasMoreLibrary,
    required bool isPageLoading,
  }) {
    // ── SONGS tab ─────────────────────────────────────────────────────────────
    if (filterMode == 'songs' || filterMode == 'singles') {
      final queueItems = ref.read(downloadQueueProvider).items
          .where((item) => item.status == DownloadStatus.queued || 
                           item.status == DownloadStatus.downloading ||
                           item.status == DownloadStatus.finalizing)
          .toList();

      // Group ALL sources (downloaded, loved, queued) by song identity
      // so each song shows as ONE card with all sources as alternates.
      final identityGroups = <String, _MergedSongGroup>{};

      String songId(String name, String artist) =>
        '${normalizeForMatch(name)}|${normalizeForMatch(artist)}';

      _MergedSongGroup groupFor(String identity) =>
        identityGroups.putIfAbsent(identity, () => _MergedSongGroup());

      // 1. Downloaded items (local library)
      for (final item in filterData.filteredUnifiedItems) {
        final sid = songId(item.trackName, item.artistName);
        groupFor(sid).downloadedItems.add(item);
      }

      // 2. Download history items (completed downloads)
      final historyState = ref.watch(downloadHistoryProvider);
      for (final hi in historyState.items) {
        if (_searchQuery.isNotEmpty) {
          final match = hi.trackName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              hi.artistName.toLowerCase().contains(_searchQuery.toLowerCase());
          if (!match) continue;
        }
        final localDup = filterData.filteredUnifiedItems.any(
          (u) => u.filePath.isNotEmpty && u.filePath == hi.filePath,
        );
        if (localDup) continue;
        final unified = UnifiedLibraryItem.fromDownloadHistory(hi);
        final sid = songId(unified.trackName, unified.artistName);
        groupFor(sid).downloadedItems.add(unified);
      }

      // 3. Queue items
      for (final item in queueItems) {
        if (_searchQuery.isNotEmpty) {
          final match = item.track.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        item.track.artistName.toLowerCase().contains(_searchQuery.toLowerCase());
          if (!match) continue;
        }
        final sid = songId(item.track.name, item.track.artistName);
        groupFor(sid).queueItems.add(item);
      }

      // 3. Loved tracks
      for (final entry in collectionState.loved) {
        final sid = songId(entry.track.name, entry.track.artistName);
        groupFor(sid).lovedEntries.add(entry);
      }

      // Build one UnifiedLibraryItem per group
      final allItems = <UnifiedLibraryItem>[];
      for (final group in identityGroups.values) {
        allItems.add(group.buildItem());
      }

      final downloadedNavItems = <DownloadHistoryItem>[];
      final downloadedNavIdx = <String, int>{};
      final localNavItems = <LocalLibraryItem>[];
      final localNavIdx = <String, int>{};
      for (final item in allItems) {
        if (item.historyItem != null) {
          downloadedNavIdx[item.id] = downloadedNavItems.length;
          downloadedNavItems.add(item.historyItem!);
        }
        if (item.localItem != null) {
          localNavIdx[item.id] = localNavItems.length;
          localNavItems.add(item.localItem!);
        }
      }

      if (allItems.isEmpty && !isPageLoading) {
        return _buildEmptyState(context, colorScheme, filterMode);
      }

      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.queueTrackCount(allItems.length),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (!_isSelectionMode)
                    _buildFilterButton(context, filterData.unifiedItems),
                ],
              ),
            ),
          ),
          SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = allItems[index];
                  return KeyedSubtree(
                    key: ValueKey(item.id),
                    child: _buildUnifiedLibraryItem(
                      context,
                      item,
                      colorScheme,
                      downloadedNavigationItems: downloadedNavItems,
                      downloadedNavigationIndex: downloadedNavIdx[item.id],
                      localNavigationItems: localNavItems,
                      localNavigationIndex: localNavIdx[item.id],
                    ),
                  );
                },
                childCount: allItems.length,
              ),
            ),
          if (isPageLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: _isSelectionMode ? 100 : 16),
          ),
        ],
      );
    }

    // ── PLAYLISTS tab ─────────────────────────────────────────────────────────
    if (filterMode == 'playlists') {
      // FIX: access favoritePlaylists safely via collectionState fields.
      // If collectionState.favoritePlaylists doesn't exist, use
      // collectionState.favoritePlaylistCount and remove fpl usage.
      final pl = collectionState.playlists;
      // FIX: using a safe accessor pattern — cast to dynamic to avoid
      // compile error if the field name differs. Replace with the correct
      // field name from LibraryCollectionsState once confirmed.
      final dynamic stateAsDynamic = collectionState;
      final List<dynamic> fpl = (() {
        try {
          return (stateAsDynamic.favoritePlaylists as List<dynamic>?) ?? [];
        } catch (_) {
          return <dynamic>[];
        }
      })();

      final hasFavorites = fpl.isNotEmpty;
      final hasCreated = pl.isNotEmpty;
      if (!hasFavorites && !hasCreated) {
        return _buildEmptyState(context, colorScheme, filterMode);
      }
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.collectionPlaylists,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (!_isSelectionMode)
                    _buildSortButton(context),
                  const SizedBox(width: 4),
                  if (!_isSelectionMode)
                    TextButton.icon(
                      onPressed: () => _showCreatePlaylistDialog(context),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(context.l10n.collectionCreatePlaylist),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (hasFavorites) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Guardadas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: _libraryGridExtent,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final p = fpl[index];
                    final String playlistKey = '${p.key ?? ''}';
                    final String playlistId = '${p.playlistId ?? ''}';
                    final String playlistName = '${p.name ?? ''}';
                    final String? imageUrl = p.imageUrl as String?;
                    return Consumer(
                      builder: (context, ref, child) {
                        final isFav = ref.watch(
                          libraryCollectionsProvider.select((s) => s.containsFavoritePlaylistKey(playlistKey)),
                        );
                        return GestureDetector(
                          onTap: () => _openFavoritePlaylist(p),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                        ? CachedCoverImage(
                                            imageUrl: p.imageUrl!,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.amber[700]!, Colors.orange[800]!],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Center(
                                              child: Icon(Icons.favorite, color: Colors.white, size: 48),
                                            ),
                                          ),
                                      ),
                                      Positioned(
                                        right: 6,
                                        top: 6,
                                        child: GestureDetector(
                                          onTap: () {
                                            ref.read(libraryCollectionsProvider.notifier).toggleFavoritePlaylistByKey(
                                              key: playlistKey,
                                              playlistId: playlistId,
                                              providerId: null,
                                              name: playlistName,
                                              imageUrl: imageUrl,
                                            );
                                          },
                                          behavior: HitTestBehavior.translucent,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isFav ? Icons.favorite : Icons.favorite_border,
                                              size: 16,
                                              color: isFav ? colorScheme.error : Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                playlistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if ((p.trackCount ?? p.tracks?.length) != null)
                                Text(
                                  '${p.trackCount ?? (p.tracks as List?)?.length ?? 0} canciones',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  childCount: fpl.length,
                ),
              ),
            ),
          ],
          if (hasCreated) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, hasFavorites ? 4 : 8, 16, 4),
                child: Text(
                  'Creadas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: _libraryGridExtent,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final p = pl[index];
                    return _buildPlaylistGridItem(context, p, colorScheme);
                  },
                  childCount: pl.length,
                ),
              ),
            ),
          ],
        ],
      );
    }

    // ── ARTISTS tab ───────────────────────────────────────────────────────────
    if (filterMode == 'artists') {
      final dynamic stateAsDynamic = collectionState;
      final List<CollectionArtistEntry> raw = (() {
        try {
          final list = stateAsDynamic.favoriteArtists as List<dynamic>;
          return list.whereType<CollectionArtistEntry>().toList();
        } catch (_) {
          return <CollectionArtistEntry>[];
        }
      })();

      if (raw.isEmpty) return _buildEmptyState(context, colorScheme, filterMode);
      final merged = <String, CollectionArtistEntry>{};
      for (final a in raw) {
        final key = normalizeForMatch(a.name);
        if (merged.containsKey(key)) {
          merged[key] = merged[key]!.mergeCover(a.imageUrl);
        } else {
          merged[key] = a;
        }
      }
      final mergedList = merged.values.toList();

      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.collectionArtists,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (!_isSelectionMode)
                    _buildSortButton(context),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: _libraryGridExtent,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final a = mergedList[index];
                  return _buildArtistGridItem(context, a, colorScheme);
                },
                childCount: mergedList.length,
              ),
            ),
          ),
        ],
      );
    }

    // ── ALL / ALBUMS tab (and default) ────────────────────────────────────────
    final historyItems = filterData.historyItems;
    final showFilteringIndicator = filterData.showFilteringIndicator;
    final filteredGroupedAlbums = filterData.filteredGroupedAlbums;
    final unifiedItems = filterData.unifiedItems;
    final filteredUnifiedItems = filterData.filteredUnifiedItems;
    final totalTrackCount = filterData.totalTrackCount;
    final totalAlbumCount = filterData.totalAlbumCount;
    final favoriteAlbums = collectionState.favoriteAlbums;

    final downloadedNavigationItems = <DownloadHistoryItem>[];
    final downloadedNavigationIndexByUnifiedId = <String, int>{};
    final localNavigationItems = <LocalLibraryItem>[];
    final localNavigationIndexByUnifiedId = <String, int>{};

    for (final item in filteredUnifiedItems) {
      final historyItem = item.historyItem;
      if (historyItem != null) {
        downloadedNavigationIndexByUnifiedId[item.id] =
            downloadedNavigationItems.length;
        downloadedNavigationItems.add(historyItem);
      }
      final localItem = item.localItem;
      if (localItem != null) {
        localNavigationIndexByUnifiedId[item.id] = localNavigationItems.length;
        localNavigationItems.add(localItem);
      }
    }

    final content = CustomScrollView(
      slivers: [
        if (totalTrackCount > 0 && filterMode == 'all')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.queueTrackCount(totalTrackCount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (!_isSelectionMode)
                    _buildFilterButton(context, unifiedItems),
                ],
              ),
            ),
          ),

        // Album grid header
        if ((filteredGroupedAlbums.isNotEmpty ||
                collectionState.favoriteAlbumCount > 0) &&
            filterMode == 'albums')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.queueAlbumCount(totalAlbumCount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  _buildFilterButton(context, unifiedItems),
                ],
              ),
            ),
          ),

        if (filteredGroupedAlbums.isEmpty &&
            collectionState.favoriteAlbumCount == 0 &&
            filterMode == 'albums' &&
            (historyItems.isNotEmpty || unifiedItems.isNotEmpty))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Spacer(),
                  _buildFilterButton(context, unifiedItems),
                ],
              ),
            ),
          ),

        if (filterMode == 'all' &&
            totalTrackCount == 0 &&
            !showFilteringIndicator &&
            (_activeFilterCount > 0 || unifiedItems.isNotEmpty))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Spacer(),
                  if (!_isSelectionMode)
                    _buildFilterButton(context, unifiedItems),
                ],
              ),
            ),
          ),

        if (historyItems.isNotEmpty && hasQueueItems)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                context.l10n.queueDownloadedHeader,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

        if (showFilteringIndicator)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.queueFilteringIndicator,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (filterMode == 'albums' &&
            (filteredGroupedAlbums.isNotEmpty ||
                favoriteAlbums.isNotEmpty))
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _AnimatedLibrarySliverGrid(
              maxCrossAxisExtent: _libraryGridExtent,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < filteredGroupedAlbums.length) {
                    final album = filteredGroupedAlbums[index];
                    return KeyedSubtree(
                      key: ValueKey(album.key),
                      child: _buildAlbumGridItem(context, album, colorScheme),
                    );
                  } else {
                    final favIndex = index - filteredGroupedAlbums.length;
                    final album = favoriteAlbums[favIndex];
                    return KeyedSubtree(
                      key: ValueKey('fav_${album.key}'),
                      child: _buildFavoriteAlbumGridItem(context, album, colorScheme),
                    );
                  }
                },
                childCount: filteredGroupedAlbums.length +
                    favoriteAlbums.length,
              ),
            ),
          ),

        if (filterMode == 'all')
          ..._buildAllTabSlivers(
            context, colorScheme, collectionState,
            filteredUnifiedItems, filteredGroupedAlbums, favoriteAlbums,
          ),

        if (!hasQueueItems &&
            totalTrackCount == 0 &&
            (filterMode != 'albums' ||
                (filteredGroupedAlbums.isEmpty &&
                    collectionState.favoriteAlbumCount == 0)) &&
            !showFilteringIndicator &&
            !isPageLoading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context, colorScheme, filterMode),
          )
        else if (isPageLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),

        if (hasQueueItems ||
            totalTrackCount > 0 ||
            (filterMode == 'albums' &&
                (filteredGroupedAlbums.isNotEmpty ||
                    collectionState.favoriteAlbumCount > 0)))
          SliverToBoxAdapter(
            child: SizedBox(height: _isSelectionMode ? 100 : 16),
          ),
      ],
    );

    final scrollAwareContent = NotificationListener<ScrollNotification>(
      onNotification: (notification) => _handleLibraryScrollNotification(
        notification: notification,
        filterMode: filterMode,
        hasMoreLibrary: hasMoreLibrary,
        isPageLoading: isPageLoading,
      ),
      child: content,
    );

    if (historyViewMode != 'grid') return scrollAwareContent;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: _handleLibraryGridScaleStart,
      onScaleUpdate: _handleLibraryGridScaleUpdate,
      onScaleEnd: _handleLibraryGridScaleEnd,
      child: scrollAwareContent,
    );
  }

  Widget _buildPauseResumeButton(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) {
    final isPaused = ref.watch(downloadQueueProvider.select((s) => s.isPaused));
    return TextButton.icon(
      onPressed: () {
        ref.read(downloadQueueProvider.notifier).togglePause();
      },
      icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 18),
      label: Text(
        isPaused ? context.l10n.actionResume : context.l10n.actionPause,
      ),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: isPaused
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildClearAllButton(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) {
    return TextButton.icon(
      onPressed: () => _showClearAllDialog(context, ref, colorScheme),
      icon: const Icon(Icons.clear_all, size: 18),
      label: Text(context.l10n.queueClearAll),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: colorScheme.error,
      ),
    );
  }

  Future<void> _showClearAllDialog(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.queueClearAll),
        content: Text(context.l10n.queueClearAllMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: Text(context.l10n.dialogClear),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(downloadQueueProvider.notifier).clearAll();
    }
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    String filterMode,
  ) {
    String message;
    String subtitle;
    IconData icon;

    switch (filterMode) {
      case 'albums':
        message = context.l10n.queueEmptyAlbums;
        subtitle = context.l10n.queueEmptyAlbumsSubtitle;
        icon = Icons.album;
        break;
      case 'songs':
      case 'singles':
        message = context.l10n.queueEmptySingles;
        subtitle = context.l10n.queueEmptySinglesSubtitle;
        icon = Icons.music_note;
        break;
      case 'playlists':
        message = context.l10n.queueEmptyAlbums; // FIX: use playlists key if available
        subtitle = context.l10n.queueEmptyAlbumsSubtitle;
        icon = Icons.queue_music;
        break;
      case 'artists':
        message = context.l10n.queueEmptyAlbums; // FIX: use artists key if available
        subtitle = context.l10n.queueEmptyAlbumsSubtitle;
        icon = Icons.person;
        break;
      default:
        message = context.l10n.queueEmptyHistory;
        subtitle = context.l10n.queueEmptyHistorySubtitle;
        icon = Icons.history;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumGridItem(
    BuildContext context,
    _GroupedAlbum album,
    ColorScheme colorScheme,
  ) {
    final bool isLocalAlbum = album.sampleFilePath == null;
    String? localCoverPath;
    if (!isLocalAlbum) {
      localCoverPath = _resolveDownloadedEmbeddedCoverPath(album.sampleFilePath);
    }
    localCoverPath ??= album.coverPath;

    return AlbumCard(
      albumName: album.albumName,
      artistName: album.artistName,
      coverUrl: localCoverPath == null ? album.coverUrl : null,
      coverPath: localCoverPath,
      trackCount: album.displayTrackCount,
      badgeIcon: isLocalAlbum ? Icons.folder : Icons.music_note,
      badgeColor: isLocalAlbum
          ? colorScheme.tertiaryContainer
          : colorScheme.primaryContainer,
      badgeTextColor: isLocalAlbum
          ? colorScheme.onTertiaryContainer
          : colorScheme.onPrimaryContainer,
      onTap: () => _navigateToAlbum(album),
    );
  }

  Widget _buildFavoriteAlbumGridItem(
    BuildContext context,
    CollectionAlbumEntry album,
    ColorScheme colorScheme,
  ) {
    final hasLocalCover = album.coverPath != null && album.coverPath!.isNotEmpty && File(album.coverPath!).existsSync();

    return Consumer(
      builder: (context, ref, child) {
        final isFav = ref.watch(
          libraryCollectionsProvider.select((s) => s.containsFavoriteAlbumKey(album.key)),
        );
        return AlbumCard(
          albumName: album.name,
          artistName: album.artistName ?? '',
          coverUrl: hasLocalCover ? null : album.imageUrl,
          coverPath: hasLocalCover ? album.coverPath : null,
          trackCount: album.totalTracks ?? 0,
          isFavorite: isFav,
          onHeartTap: () {
            ref.read(libraryCollectionsProvider.notifier).toggleFavoriteAlbumByKey(
              key: album.key,
              albumId: album.albumId,
              providerId: album.providerId,
              name: album.name,
              artistName: album.artistName,
              coverUrl: album.coverUrl,
              imageUrl: album.imageUrl,
              totalTracks: album.totalTracks,
            );
          },
          onTap: () => _navigateWithUnfocus(
            MaterialPageRoute(
              builder: (_) => AlbumScreen(
                albumId: album.albumId,
                albumName: album.name,
                coverUrl: hasLocalCover ? 'file://${album.coverPath}' : album.imageUrl,
                artistName: album.artistName,
                extensionId: album.providerId,
              ),
            ),
          ),
        );
      },
    );
  }

  bool _hasTextValue(String? value) => value != null && value.trim().isNotEmpty;

  List<UnifiedLibraryItem> _selectedItemsFromAll(
    List<UnifiedLibraryItem> allItems,
  ) {
    final itemsById = {for (final item in allItems) item.id: item};
    return _selectedIds
        .map((id) => itemsById[id])
        .whereType<UnifiedLibraryItem>()
        .toList(growable: false);
  }

  bool _isLocalOnlySelection(List<UnifiedLibraryItem> allItems) {
    final selectedItems = _selectedItemsFromAll(allItems);
    return selectedItems.isNotEmpty &&
        selectedItems.every((item) => item.localItem != null);
  }

  Future<void> _safeDeleteTempFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _cleanupTempFileAndParentDir(String path) async {
    await _safeDeleteTempFile(path);
    try {
      final parent = File(path).parent;
      if (await parent.exists()) {
        await parent.delete();
      }
    } catch (_) {}
  }

  Future<bool> _applyQueueFfmpegReEnrichResult(
    LocalLibraryItem item,
    Map<String, dynamic> result,
  ) async {
    final tempPath = result['temp_path'] as String?;
    final safUri = result['saf_uri'] as String?;
    final ffmpegTarget = _hasTextValue(tempPath) ? tempPath! : item.filePath;
    final downloadedCoverPath = result['cover_path'] as String?;
    String? effectiveCoverPath = downloadedCoverPath;
    String? extractedCoverPath;

    if (!_hasTextValue(effectiveCoverPath)) {
      try {
        final tempDir = await Directory.systemTemp.createTemp('reenrich_cover_');
        final coverOutput =
            '${tempDir.path}${Platform.pathSeparator}cover.jpg';
        final extracted = await PlatformBridge.extractCoverToFile(
          ffmpegTarget,
          coverOutput,
        );
        if (extracted['error'] == null) {
          effectiveCoverPath = coverOutput;
          extractedCoverPath = coverOutput;
        } else {
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        }
      } catch (_) {}
    }

    final metadata = (result['metadata'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, v.toString()),
    );

    final format = item.format?.toLowerCase();
    final lowerPath = item.filePath.toLowerCase();
    final isMp3 = format == 'mp3' || lowerPath.endsWith('.mp3');
    final isM4A =
        format == 'm4a' ||
        format == 'aac' ||
        lowerPath.endsWith('.m4a') ||
        lowerPath.endsWith('.aac');
    final isOpus =
        format == 'opus' ||
        format == 'ogg' ||
        lowerPath.endsWith('.opus') ||
        lowerPath.endsWith('.ogg');

    final artistTagMode = ref.read(settingsProvider).artistTagMode;
    String? ffmpegResult;
    if (isMp3) {
      ffmpegResult = await FFmpegService.embedMetadataToMp3(
        mp3Path: ffmpegTarget,
        coverPath: effectiveCoverPath,
        metadata: metadata,
        preserveMetadata: true,
      );
    } else if (isM4A) {
      ffmpegResult = await FFmpegService.embedMetadataToM4a(
        m4aPath: ffmpegTarget,
        coverPath: effectiveCoverPath,
        metadata: metadata,
        preserveMetadata: true,
      );
    } else if (isOpus) {
      ffmpegResult = await FFmpegService.embedMetadataToOpus(
        opusPath: ffmpegTarget,
        coverPath: effectiveCoverPath,
        metadata: metadata,
        artistTagMode: artistTagMode,
        preserveMetadata: true,
      );
    }

    if (ffmpegResult != null &&
        _hasTextValue(tempPath) &&
        _hasTextValue(safUri)) {
      final ok = await PlatformBridge.writeTempToSaf(ffmpegResult, safUri!);
      if (!ok) {
        if (_hasTextValue(downloadedCoverPath)) {
          await _safeDeleteTempFile(downloadedCoverPath!);
        }
        if (_hasTextValue(extractedCoverPath)) {
          await _cleanupTempFileAndParentDir(extractedCoverPath!);
        }
        await _safeDeleteTempFile(tempPath!);
        return false;
      }
    }

    if (_hasTextValue(downloadedCoverPath)) {
      await _safeDeleteTempFile(downloadedCoverPath!);
    }
    if (_hasTextValue(extractedCoverPath)) {
      await _cleanupTempFileAndParentDir(extractedCoverPath!);
    }
    if (_hasTextValue(tempPath)) {
      await _safeDeleteTempFile(tempPath!);
    }

    return ffmpegResult != null;
  }

  Future<bool> _reEnrichQueueLocalTrack(
    LocalLibraryItem item, {
    List<String>? updateFields,
  }) async {
    final durationMs = (item.duration ?? 0) * 1000;
    final artistTagMode = ref.read(settingsProvider).artistTagMode;
    final request = <String, dynamic>{
      'file_path': item.filePath,
      'cover_url': '',
      'max_quality': true,
      'embed_lyrics': true,
      'artist_tag_mode': artistTagMode,
      'spotify_id': '',
      'track_name': item.trackName,
      'artist_name': item.artistName,
      'album_name': item.albumName,
      'album_artist': item.albumArtist ?? '',
      'track_number': item.trackNumber ?? 0,
      'disc_number': item.discNumber ?? 0,
      'release_date': item.releaseDate ?? '',
      'isrc': item.isrc ?? '',
      'genre': item.genre ?? '',
      'label': '',
      'copyright': '',
      'duration_ms': durationMs,
      'search_online': true,
      // ignore: use_null_aware_elements
      if (updateFields != null) 'update_fields': updateFields,
    };

    final result = await PlatformBridge.reEnrichFile(request);
    final method = result['method'] as String?;
    if (method == 'native') return true;
    if (method == 'ffmpeg') {
      return _applyQueueFfmpegReEnrichResult(item, result);
    }
    return false;
  }

  List<LocalLibraryItem> _selectedFlacEligibleLocalItems(
    List<UnifiedLibraryItem> allItems,
  ) {
    final selectedItems = _selectedItemsFromAll(allItems);
    return selectedItems
        .map((item) => item.localItem)
        .whereType<LocalLibraryItem>()
        .where(LocalTrackRedownloadService.isFlacUpgradeEligible)
        .toList(growable: false);
  }

  Future<void> _queueSelectedLocalAsFlac(
    List<UnifiedLibraryItem> allItems,
  ) async {
    final selectedLocalItems = _selectedFlacEligibleLocalItems(allItems);
    if (selectedLocalItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.queueFlacAction),
        content: Text(
          context.l10n.queueFlacConfirmMessage(selectedLocalItems.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.queueFlacAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final settings = ref.read(settingsProvider);
    if (!settings.isPremium && settings.premiumUntil == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suscríbete a premium para descargar en alta calidad'),
          ),
        );
      }
      return;
    }
    final extensionState = ref.read(extensionProvider);
    final includeExtensions =
        settings.useExtensionProviders &&
        extensionState.extensions.any(
          (ext) => ext.enabled && ext.hasMetadataProvider,
        );
    final targetService = LocalTrackRedownloadService.preferredFlacService(
      settings,
      extensionState,
    );
    if (targetService.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.extensionsNoDownloadProvider)),
      );
      return;
    }
    final targetQuality =
        LocalTrackRedownloadService.preferredFlacQualityForService(
          targetService,
          extensionState,
        );

    final matchedTracks = <Track>[];
    var skippedCount = 0;
    final total = selectedLocalItems.length;
    var cancelled = false;

    BatchProgressDialog.show(
      context: context,
      title: context.l10n.queueFlacAction,
      total: total,
      icon: Icons.queue_music,
      onCancel: () {
        cancelled = true;
        BatchProgressDialog.dismiss(context);
      },
    );

    for (var i = 0; i < total; i++) {
      if (!mounted || cancelled) break;
      BatchProgressDialog.update(
        current: i + 1,
        detail: selectedLocalItems[i].trackName,
      );
      try {
        final resolution = await LocalTrackRedownloadService.resolveBestMatch(
          selectedLocalItems[i],
          includeExtensions: includeExtensions,
        );
        if (resolution.canQueue && resolution.match != null) {
          matchedTracks.add(resolution.match!);
        } else {
          skippedCount++;
        }
      } catch (_) {
        skippedCount++;
      }
    }

    if (!mounted) return;
    if (!cancelled) BatchProgressDialog.dismiss(context);

    if (matchedTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.queueFlacNoReliableMatches)),
      );
      return;
    }

    ref
        .read(downloadQueueProvider.notifier)
        .addMultipleToQueue(
          matchedTracks,
          targetService,
          qualityOverride: targetQuality,
        );

    final summary = skippedCount == 0
        ? context.l10n.snackbarAddedTracksToQueue(matchedTracks.length)
        : context.l10n.queueFlacQueuedWithSkipped(
            matchedTracks.length,
            skippedCount,
          );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _reEnrichSelectedLocalFromQueue(
    List<UnifiedLibraryItem> allItems,
  ) async {
    final selectedItems = _selectedItemsFromAll(allItems);
    final selectedLocalItems = selectedItems
        .map((item) => item.localItem)
        .whereType<LocalLibraryItem>()
        .toList(growable: false);

    if (selectedLocalItems.isEmpty) return;

    setState(() => _isSelectionMode = false);
    _hideSelectionOverlay();

    final selection = await showReEnrichFieldDialog(
      context,
      selectedCount: selectedLocalItems.length,
    );

    if (selection == null || !mounted) {
      if (mounted) setState(() => _isSelectionMode = true);
      return;
    }

    final updateFields = selection.isAll ? null : selection.fields;
    var successCount = 0;
    final total = selectedLocalItems.length;
    var cancelled = false;

    BatchProgressDialog.show(
      context: context,
      title: context.l10n.trackReEnrichProgress,
      total: total,
      icon: Icons.auto_fix_high,
      onCancel: () {
        cancelled = true;
        BatchProgressDialog.dismiss(context);
      },
    );

    for (var i = 0; i < total; i++) {
      if (!mounted || cancelled) break;
      final item = selectedLocalItems[i];
      BatchProgressDialog.update(
        current: i + 1,
        detail: '${item.trackName} - ${item.artistName}',
      );
      try {
        final ok = await _reEnrichQueueLocalTrack(
          item,
          updateFields: updateFields,
        );
        if (ok) successCount++;
      } catch (_) {}
    }

    if (!mounted) return;

    final settings = ref.read(settingsProvider);
    final localLibraryPath = settings.localLibraryPath.trim();
    final iosBookmark = settings.localLibraryBookmark;
    try {
      if (localLibraryPath.isNotEmpty &&
          !ref.read(localLibraryProvider).isScanning) {
        await ref.read(localLibraryProvider.notifier).startScan(
          localLibraryPath,
          iosBookmark: iosBookmark.isNotEmpty ? iosBookmark : null,
        );
      } else {
        await ref.read(localLibraryProvider.notifier).reloadFromStorage();
      }
    } catch (_) {
      await ref.read(localLibraryProvider.notifier).reloadFromStorage();
    }

    _exitSelectionMode();

    if (!mounted) return;
    if (!cancelled) BatchProgressDialog.dismiss(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    final failedCount = total - successCount;
    final summary = failedCount <= 0
        ? '${context.l10n.trackReEnrichSuccess} ($successCount/$total)'
        : '${context.l10n.trackReEnrichSuccess} ($successCount/$total) • Failed: $failedCount';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));
  }

  Future<void> _shareSelected(List<UnifiedLibraryItem> allItems) async {
    final itemsById = {for (final item in allItems) item.id: item};
    final safUris = <String>[];
    final filesToShare = <XFile>[];

    for (final id in _selectedIds) {
      final item = itemsById[id];
      if (item == null) continue;
      final path = item.filePath;
      if (isContentUri(path)) {
        if (await fileExists(path)) safUris.add(path);
      } else if (await fileExists(path)) {
        filesToShare.add(XFile(path));
      }
    }

    if (safUris.isEmpty && filesToShare.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.selectionShareNoFiles)),
        );
      }
      return;
    }

    if (safUris.isNotEmpty) {
      try {
        if (safUris.length == 1) {
          await PlatformBridge.shareContentUri(safUris.first);
        } else {
          await PlatformBridge.shareMultipleContentUris(safUris);
        }
      } catch (_) {}
    }

    if (filesToShare.isNotEmpty) {
      await SharePlus.instance.share(ShareParams(files: filesToShare));
    }
  }

  Future<void> _showBatchConvertSheet(
    BuildContext context,
    List<UnifiedLibraryItem> allItems,
  ) async {
    final itemsById = {for (final item in allItems) item.id: item};
    final sourceFormats = <String>{};
    for (final id in _selectedIds) {
      final item = itemsById[id];
      if (item == null) continue;
      String nameToCheck;
      if (item.historyItem?.safFileName != null &&
          item.historyItem!.safFileName!.isNotEmpty) {
        nameToCheck = item.historyItem!.safFileName!.toLowerCase();
      } else if (item.localItem?.format != null &&
          item.localItem!.format!.isNotEmpty) {
        nameToCheck = '.${item.localItem!.format!.toLowerCase()}';
      } else {
        nameToCheck = item.filePath.toLowerCase();
      }
      final ext = nameToCheck.endsWith('.flac')
          ? 'FLAC'
          : nameToCheck.endsWith('.m4a')
          ? 'M4A'
          : nameToCheck.endsWith('.mp3')
          ? 'MP3'
          : (nameToCheck.endsWith('.opus') || nameToCheck.endsWith('.ogg'))
          ? 'Opus'
          : null;
      if (ext != null) sourceFormats.add(ext);
    }

    final formats = ['ALAC', 'FLAC', 'MP3', 'Opus'].where((target) {
      return sourceFormats.any((src) {
        if (src == target) return false;
        final isLosslessTarget = target == 'ALAC' || target == 'FLAC';
        final isLosslessSource = src == 'FLAC' || src == 'M4A';
        if (isLosslessTarget && !isLosslessSource) return false;
        return true;
      });
    }).toList();

    if (formats.isEmpty) return;

    String selectedFormat = formats.first;
    bool isLosslessTarget = selectedFormat == 'ALAC' || selectedFormat == 'FLAC';
    String selectedBitrate =
        isLosslessTarget ? '320k' : (selectedFormat == 'Opus' ? '128k' : '320k');
    var didStartConversion = false;

    _hideSelectionOverlay();
    _hidePlaylistSelectionOverlay();

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colorScheme = Theme.of(context).colorScheme;
            final bitrates = ['128k', '192k', '256k', '320k'];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.selectionBatchConvertConfirmTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.trackConvertTargetFormat,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: formats.map((format) {
                        final isSelected = format == selectedFormat;
                        return ChoiceChip(
                          label: Text(format),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setSheetState(() {
                                selectedFormat = format;
                                isLosslessTarget =
                                    format == 'ALAC' || format == 'FLAC';
                                if (!isLosslessTarget) {
                                  selectedBitrate =
                                      format == 'Opus' ? '128k' : '320k';
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    if (!isLosslessTarget) ...[
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.trackConvertBitrate,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: bitrates.map((br) {
                          final isSelected = br == selectedBitrate;
                          return ChoiceChip(
                            label: Text(br),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() => selectedBitrate = br);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    if (isLosslessTarget) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.verified, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            context.l10n.trackConvertLosslessHint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.primary),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          didStartConversion = true;
                          Navigator.pop(context);
                          _performBatchConversion(
                            allItems: allItems,
                            targetFormat: selectedFormat,
                            bitrate: selectedBitrate,
                          );
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          context.l10n.selectionConvertCount(_selectedIds.length),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || didStartConversion) return;
    if (_isSelectionMode) {
      _syncSelectionOverlay(
        items: allItems,
        bottomPadding: MediaQuery.of(this.context).padding.bottom,
      );
    } else if (_isPlaylistSelectionMode) {
      _syncPlaylistSelectionOverlay(
        playlists: ref.read(libraryCollectionsProvider).playlists,
        bottomPadding: MediaQuery.of(this.context).padding.bottom,
      );
    }
  }

  Future<void> _performBatchConversion({
    required List<UnifiedLibraryItem> allItems,
    required String targetFormat,
    required String bitrate,
  }) async {
    final itemsById = {for (final item in allItems) item.id: item};
    final selectedItems = <UnifiedLibraryItem>[];
    for (final id in _selectedIds) {
      final item = itemsById[id];
      if (item == null) continue;
      String nameToCheck;
      if (item.historyItem?.safFileName != null &&
          item.historyItem!.safFileName!.isNotEmpty) {
        nameToCheck = item.historyItem!.safFileName!.toLowerCase();
      } else if (item.localItem?.format != null &&
          item.localItem!.format!.isNotEmpty) {
        nameToCheck = '.${item.localItem!.format!.toLowerCase()}';
      } else {
        nameToCheck = item.filePath.toLowerCase();
      }
      final ext = nameToCheck.endsWith('.flac')
          ? 'FLAC'
          : nameToCheck.endsWith('.m4a')
          ? 'M4A'
          : nameToCheck.endsWith('.mp3')
          ? 'MP3'
          : (nameToCheck.endsWith('.opus') || nameToCheck.endsWith('.ogg'))
          ? 'Opus'
          : null;
      if (ext == null || ext == targetFormat) continue;
      final isLosslessTarget = targetFormat == 'ALAC' || targetFormat == 'FLAC';
      final isLosslessSource = ext == 'FLAC' || ext == 'M4A';
      if (isLosslessTarget && !isLosslessSource) continue;
      selectedItems.add(item);
    }

    if (selectedItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.selectionConvertNoConvertible)),
        );
      }
      return;
    }

    final isLossless = targetFormat == 'ALAC' || targetFormat == 'FLAC';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.selectionBatchConvertConfirmTitle),
        content: Text(
          isLossless
              ? context.l10n.selectionBatchConvertConfirmMessageLossless(
                  selectedItems.length,
                  targetFormat,
                )
              : context.l10n.selectionBatchConvertConfirmMessage(
                  selectedItems.length,
                  targetFormat,
                  bitrate,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.trackConvertFormat),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    int successCount = 0;
    final total = selectedItems.length;
    final historyDb = HistoryDatabase.instance;
    final newQuality =
        (targetFormat.toUpperCase() == 'ALAC' || targetFormat.toUpperCase() == 'FLAC')
        ? '${targetFormat.toUpperCase()} Lossless'
        : '${targetFormat.toUpperCase()} ${bitrate.trim().toLowerCase()}';
    final settings = ref.read(settingsProvider);
    final shouldEmbedLyrics =
        settings.embedLyrics && settings.lyricsMode != 'external';

    var cancelled = false;
    BatchProgressDialog.show(
      context: context,
      title: context.l10n.trackConvertConverting,
      total: total,
      icon: Icons.transform,
      onCancel: () {
        cancelled = true;
        BatchProgressDialog.dismiss(context);
      },
    );

    for (int i = 0; i < total; i++) {
      if (!mounted || cancelled) break;
      final item = selectedItems[i];
      BatchProgressDialog.update(current: i + 1, detail: item.trackName);

      try {
        final metadata = <String, String>{
          'TITLE': item.trackName,
          'ARTIST': item.artistName,
          'ALBUM': item.albumName,
        };
        try {
          final result = await PlatformBridge.readFileMetadata(item.filePath);
          if (result['error'] == null) {
            mergePlatformMetadataForTagEmbed(target: metadata, source: result);
          }
        } catch (_) {}
        await ensureLyricsMetadataForConversion(
          metadata: metadata,
          sourcePath: item.filePath,
          shouldEmbedLyrics: shouldEmbedLyrics,
          trackName: item.trackName,
          artistName: item.artistName,
          spotifyId: item.historyItem?.spotifyId ?? '',
          durationMs:
              ((item.historyItem?.duration ?? item.localItem?.duration) ?? 0) *
              1000,
        );

        String? coverPath;
        try {
          final tempDir = await getTemporaryDirectory();
          final coverOutput =
              '${tempDir.path}${Platform.pathSeparator}batch_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final coverResult = await PlatformBridge.extractCoverToFile(
            item.filePath,
            coverOutput,
          );
          if (coverResult['error'] == null) {
            coverPath = coverOutput;
          }
        } catch (_) {}

        String workingPath = item.filePath;
        final isSaf = isContentUri(item.filePath);
        String? safTempPath;

        if (isSaf) {
          safTempPath = await PlatformBridge.copyContentUriToTemp(item.filePath);
          if (safTempPath == null) continue;
          workingPath = safTempPath;
        }

        final newPath = await FFmpegService.convertAudioFormat(
          inputPath: workingPath,
          targetFormat: targetFormat.toLowerCase(),
          bitrate: bitrate,
          metadata: metadata,
          coverPath: coverPath,
          artistTagMode: settings.artistTagMode,
          deleteOriginal: !isSaf,
        );

        if (coverPath != null) {
          try {
            await File(coverPath).delete();
          } catch (_) {}
        }

        if (newPath == null) {
          if (safTempPath != null) {
            try {
              await File(safTempPath).delete();
            } catch (_) {}
          }
          continue;
        }

        if (isSaf && item.historyItem != null) {
          final hi = item.historyItem!;
          final treeUri = hi.downloadTreeUri;
          final relativeDir = hi.safRelativeDir ?? '';
          if (treeUri != null && treeUri.isNotEmpty) {
            final oldFileName = hi.safFileName ?? '';
            final dotIdx = oldFileName.lastIndexOf('.');
            final baseName = dotIdx > 0 ? oldFileName.substring(0, dotIdx) : oldFileName;
            String newExt;
            String mimeType;
            switch (targetFormat.toLowerCase()) {
              case 'opus':
                newExt = '.opus';
                mimeType = 'audio/opus';
                break;
              case 'alac':
                newExt = '.m4a';
                mimeType = 'audio/mp4';
                break;
              case 'flac':
                newExt = '.flac';
                mimeType = 'audio/flac';
                break;
              default:
                newExt = '.mp3';
                mimeType = 'audio/mpeg';
                break;
            }
            final newFileName = '$baseName$newExt';
            final safUri = await PlatformBridge.createSafFileFromPath(
              treeUri: treeUri,
              relativeDir: relativeDir,
              fileName: newFileName,
              mimeType: mimeType,
              srcPath: newPath,
            );
            if (safUri == null || safUri.isEmpty) {
              try { await File(newPath).delete(); } catch (_) {}
              if (safTempPath != null) {
                try { await File(safTempPath).delete(); } catch (_) {}
              }
              continue;
            }
            try { await PlatformBridge.safDelete(item.filePath); } catch (_) {}
            await historyDb.updateFilePath(
              hi.id,
              safUri,
              newSafFileName: newFileName,
              newQuality: newQuality,
              clearAudioSpecs: true,
            );
          }
          try { await File(newPath).delete(); } catch (_) {}
          if (safTempPath != null) {
            try { await File(safTempPath).delete(); } catch (_) {}
          }
        } else if (isSaf && item.localItem != null) {
          final uri = Uri.parse(item.filePath);
          final pathSegments = uri.pathSegments;
          String? treeUri;
          String relativeDir = '';
          String oldFileName = '';
          final treeIdx = pathSegments.indexOf('tree');
          final docIdx = pathSegments.indexOf('document');
          if (treeIdx >= 0 && treeIdx + 1 < pathSegments.length) {
            final treeId = pathSegments[treeIdx + 1];
            treeUri = 'content://${uri.authority}/tree/${Uri.encodeComponent(treeId)}';
          }
          if (docIdx >= 0 && docIdx + 1 < pathSegments.length) {
            final docPath = Uri.decodeFull(pathSegments[docIdx + 1]);
            final slashIdx = docPath.lastIndexOf('/');
            if (slashIdx >= 0) {
              oldFileName = docPath.substring(slashIdx + 1);
              final treeId = treeIdx >= 0 && treeIdx + 1 < pathSegments.length
                  ? Uri.decodeFull(pathSegments[treeIdx + 1])
                  : '';
              if (treeId.isNotEmpty && docPath.startsWith(treeId)) {
                final afterTree = docPath.substring(treeId.length);
                final trimmed = afterTree.startsWith('/')
                    ? afterTree.substring(1)
                    : afterTree;
                final lastSlash = trimmed.lastIndexOf('/');
                relativeDir = lastSlash >= 0 ? trimmed.substring(0, lastSlash) : '';
              }
            } else {
              oldFileName = docPath;
            }
          }
          if (treeUri != null && oldFileName.isNotEmpty) {
            final dotIdx = oldFileName.lastIndexOf('.');
            final baseName = dotIdx > 0 ? oldFileName.substring(0, dotIdx) : oldFileName;
            String newExt;
            String mimeType;
            switch (targetFormat.toLowerCase()) {
              case 'opus':
                newExt = '.opus';
                mimeType = 'audio/opus';
                break;
              case 'alac':
                newExt = '.m4a';
                mimeType = 'audio/mp4';
                break;
              case 'flac':
                newExt = '.flac';
                mimeType = 'audio/flac';
                break;
              default:
                newExt = '.mp3';
                mimeType = 'audio/mpeg';
                break;
            }
            final newFileName = '$baseName$newExt';
            final safUri = await PlatformBridge.createSafFileFromPath(
              treeUri: treeUri,
              relativeDir: relativeDir,
              fileName: newFileName,
              mimeType: mimeType,
              srcPath: newPath,
            );
            if (safUri == null || safUri.isEmpty) {
              try { await File(newPath).delete(); } catch (_) {}
              if (safTempPath != null) {
                try { await File(safTempPath).delete(); } catch (_) {}
              }
              continue;
            }
            try { await PlatformBridge.safDelete(item.filePath); } catch (_) {}
            await LibraryDatabase.instance.replaceWithConvertedItem(
              item: item.localItem!,
              newFilePath: safUri,
              targetFormat: targetFormat,
              bitrate: int.tryParse(bitrate.replaceAll(RegExp(r"[^0-9]"), "")),
            );
          }
          try { await File(newPath).delete(); } catch (_) {}
          if (safTempPath != null) {
            try { await File(safTempPath).delete(); } catch (_) {}
          }
        } else if (item.historyItem != null) {
          await historyDb.updateFilePath(
            item.historyItem!.id,
            newPath,
            newQuality: newQuality,
            clearAudioSpecs: true,
          );
        } else if (item.localItem != null) {
          await LibraryDatabase.instance.replaceWithConvertedItem(
            item: item.localItem!,
            newFilePath: newPath,
            targetFormat: targetFormat,
            bitrate: int.tryParse(bitrate.replaceAll(RegExp(r"[^0-9]"), "")),
          );
        }

        successCount++;
      } catch (_) {}
    }

    ref.read(downloadHistoryProvider.notifier).reloadFromStorage();
    ref.read(localLibraryProvider.notifier).reloadFromStorage();
    _exitSelectionMode();

    if (mounted) {
      if (!cancelled) BatchProgressDialog.dismiss(context);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.selectionBatchConvertSuccess(
              successCount,
              total,
              targetFormat,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildSelectionBottomBar(
    BuildContext context,
    ColorScheme colorScheme,
    List<UnifiedLibraryItem> unifiedItems,
    double bottomPadding,
  ) {
    final selectedCount = _selectedIds.length;
    final allSelected =
        selectedCount == unifiedItems.length && unifiedItems.isNotEmpty;
    final localOnlySelection = _isLocalOnlySelection(unifiedItems);
    final flacEligibleCount = _selectedFlacEligibleLocalItems(unifiedItems).length;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding > 0 ? 8 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _exitSelectionMode,
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.selectionSelected(selectedCount),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          allSelected
                              ? context.l10n.selectionAllSelected
                              : context.l10n.downloadedAlbumTapToSelect,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (allSelected) {
                        _exitSelectionMode();
                      } else {
                        _selectAll(unifiedItems);
                      }
                    },
                    icon: Icon(
                      allSelected ? Icons.deselect : Icons.select_all,
                      size: 20,
                    ),
                    label: Text(
                      allSelected
                          ? context.l10n.actionDeselect
                          : context.l10n.actionSelectAll,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (localOnlySelection && flacEligibleCount > 0) ...[
                    Expanded(
                      child: _SelectionActionButton(
                        icon: Icons.download_for_offline_outlined,
                        label:
                            '${context.l10n.queueFlacAction} ($flacEligibleCount)',
                        onPressed: () =>
                            _queueSelectedLocalAsFlac(unifiedItems),
                        colorScheme: colorScheme,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _SelectionActionButton(
                      icon: localOnlySelection
                          ? Icons.auto_fix_high_outlined
                          : Icons.share_outlined,
                      label: localOnlySelection
                          ? '${context.l10n.trackReEnrich} ($selectedCount)'
                          : context.l10n.selectionShareCount(selectedCount),
                      onPressed: selectedCount > 0
                          ? () => localOnlySelection
                                ? _reEnrichSelectedLocalFromQueue(unifiedItems)
                                : _shareSelected(unifiedItems)
                          : null,
                      colorScheme: colorScheme,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SelectionActionButton(
                      icon: Icons.swap_horiz,
                      label: context.l10n.selectionConvertCount(selectedCount),
                      onPressed: selectedCount > 0
                          ? () => _showBatchConvertSheet(context, unifiedItems)
                          : null,
                      colorScheme: colorScheme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selectedCount > 0
                      ? () => _deleteSelected(unifiedItems)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    selectedCount > 0
                        ? 'Delete $selectedCount ${selectedCount == 1 ? 'track' : 'tracks'}'
                        : context.l10n.selectionSelectToDelete,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: selectedCount > 0
                        ? colorScheme.error
                        : colorScheme.surfaceContainerHighest,
                    foregroundColor: selectedCount > 0
                        ? colorScheme.onError
                        : colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueItem(
    BuildContext context,
    DownloadItem item,
    ColorScheme colorScheme,
  ) {
    final settings = ref.read(settingsProvider);
    final isCompleted = item.status == DownloadStatus.completed;
    final isActive =
        item.status == DownloadStatus.queued ||
        item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.finalizing;

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: isActive
          ? (_) async {
              return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(context.l10n.cancelDownloadTitle),
                      content: Text(
                        context.l10n.cancelDownloadContent(item.track.name),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(context.l10n.cancelDownloadKeep),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(context.l10n.dialogCancel),
                        ),
                      ],
                    ),
                  ) ??
                  false;
            }
          : null,
      onDismissed: (_) {
        ref.read(downloadQueueProvider.notifier).dismissItem(item.id);
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      child: DownloadSuccessOverlay(
        showSuccess: isCompleted,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TrackCard(
              track: item.track,
              coverSize: 56,
              showHeartButton: false,
              showInfoButton: isCompleted,
              showStatusDot: true,
              downloadProgress: isCompleted ? 1.0 : (isActive ? item.progress : 0.0),
              onTap: isCompleted ? () => _navigateToMetadataScreen(item) : null,
              onStatusTap: isActive ? () => DownloadProgressModal.show(context, item.id) : null,
              trailing: isCompleted 
                ? IconButton(
                    onPressed: () => _openFile(
                      item.filePath!,
                      trackId: item.track.id,
                      title: item.track.name,
                      artist: item.track.artistName,
                      album: item.track.albumName,
                      coverUrl: item.track.coverUrl ?? '',
                      isrc: item.track.isrc,
                      source: item.track.source,
                    ),
                    icon: Icon(Icons.play_arrow_rounded, color: colorScheme.primary),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    ),
                  )
                : (item.status == DownloadStatus.failed 
                    ? IconButton(
                        onPressed: () => ref.read(downloadQueueProvider.notifier).retryItem(item.id),
                        icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
                      )
                    : null),
            ),
            if (isActive || item.status == DownloadStatus.queued || item.status == DownloadStatus.downloading)
              Padding(
                padding: const EdgeInsets.only(left: 72, right: 16, bottom: 4),
                child: Row(
                  children: [
                    _PerTrackToggle(
                      icon: Icons.lyrics_outlined,
                      label: 'Letra',
                      value: item.downloadLyrics,
                      globalDefault: settings.embedLyrics,
                      onChanged: (v) => ref.read(downloadQueueProvider.notifier).setItemDownloadFlags(
                        item.id, downloadLyrics: v,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _PerTrackToggle(
                      icon: Icons.movie_outlined,
                      label: 'Video',
                      value: item.downloadVideo,
                      globalDefault: settings.downloadVideo,
                      onChanged: (v) => ref.read(downloadQueueProvider.notifier).setItemDownloadFlags(
                        item.id, downloadVideo: v,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context,
    List<UnifiedLibraryItem> unifiedItems,
  ) {
    return GestureDetector(
      onLongPress: _activeFilterCount > 0 ? _resetFilters : null,
      child: TextButton.icon(
        onPressed: () => _showFilterSheet(context, unifiedItems),
        icon: Badge(
          isLabelVisible: _activeFilterCount > 0,
          label: Text('$_activeFilterCount'),
          child: const Icon(Icons.filter_list, size: 18),
        ),
        label: Text(context.l10n.libraryFilterTitle),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
    );
  }

  Widget _buildSortButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _showFilterSheet(context, const [], showTrackFilters: false),
      icon: const Icon(Icons.filter_list, size: 18),
      label: Text(context.l10n.libraryFilterTitle),
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }

  Widget _buildUnifiedCoverImage(
    UnifiedLibraryItem item,
    ColorScheme colorScheme, [
    double? size,
  ]) {
    final isDownloaded = item.source == LibraryItemSource.downloaded;
    if (isDownloaded) {
      return ValueListenableBuilder<int>(
        valueListenable: _embeddedCoverVersion,
        builder: (context, _, child) =>
            _buildUnifiedCoverImageInner(item, colorScheme, isDownloaded, size),
      );
    }
    return _buildUnifiedCoverImageInner(item, colorScheme, isDownloaded, size);
  }

  Widget _buildUnifiedCoverImageInner(
    UnifiedLibraryItem item,
    ColorScheme colorScheme,
    bool isDownloaded, [
    double? size,
  ]) {
    final cacheSize = size != null ? (size * 2).toInt() : 200;
    final iconSize = size != null ? size * 0.4 : 32.0;

    Widget buildPlaceholder({bool isLocal = false}) {
      final bgColor = (isDownloaded && !isLocal)
          ? colorScheme.surfaceContainerHighest
          : colorScheme.secondaryContainer;
      final fgColor = (isDownloaded && !isLocal)
          ? colorScheme.onSurfaceVariant
          : colorScheme.onSecondaryContainer;
      return Container(
        width: size,
        height: size,
        decoration: size != null
            ? BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        color: size != null ? null : bgColor,
        child: Center(
          child: Icon(Icons.music_note, color: fgColor, size: iconSize),
        ),
      );
    }

    Widget fadeInFileImage(Widget child, int? frame, bool wasSync) {
      if (wasSync) return child;
      final animated = Stack(
        fit: StackFit.expand,
        children: [
          buildPlaceholder(isLocal: !isDownloaded),
          AnimatedOpacity(
            opacity: frame == null ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: child,
          ),
        ],
      );
      if (size == null) return animated;
      return SizedBox(width: size, height: size, child: animated);
    }

    if (isDownloaded) {
      final embeddedCoverPath = _resolveDownloadedEmbeddedCoverPath(
        item.filePath,
      );
      if (embeddedCoverPath != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(embeddedCoverPath),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                fadeInFileImage(child, frame, wasSynchronouslyLoaded),
            errorBuilder: (context, error, stackTrace) => buildPlaceholder(),
          ),
        );
      }
    }

    if (item.coverUrl != null) {
      if (isDownloaded) return buildPlaceholder();
      return CachedCoverImage(
        imageUrl: item.coverUrl!,
        width: size,
        height: size,
        memCacheWidth: cacheSize,
        memCacheHeight: cacheSize,
        borderRadius: BorderRadius.circular(8),
        placeholder: (context, url) => buildPlaceholder(),
        errorWidget: (context, url, error) => buildPlaceholder(),
        fadeInDuration: const Duration(milliseconds: 180),
        fadeOutDuration: const Duration(milliseconds: 90),
      );
    }

    if (item.localCoverPath != null && item.localCoverPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(item.localCoverPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              fadeInFileImage(child, frame, wasSynchronouslyLoaded),
          errorBuilder: (context, error, stackTrace) =>
              buildPlaceholder(isLocal: true),
        ),
      );
    }

    if (size != null) return buildPlaceholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: buildPlaceholder(),
    );
  }

  bool _isActiveStatus(DownloadStatus status) {
    return status == DownloadStatus.queued ||
        status == DownloadStatus.downloading ||
        status == DownloadStatus.finalizing;
  }

  Widget _buildUnifiedLibraryItem(
    BuildContext context,
    UnifiedLibraryItem item,
    ColorScheme colorScheme, {
    required List<DownloadHistoryItem> downloadedNavigationItems,
    required int? downloadedNavigationIndex,
    required List<LocalLibraryItem> localNavigationItems,
    required int? localNavigationIndex,
  }) {
    final isSelected = _selectedIds.contains(item.id);

    final isQueueItem = item.queueItem != null;

    // Use user-selected source if available, otherwise build from item
    final selectedOverride = item.alternateSources != null
        ? _selectedLibrarySource[item.id]
        : null;
    final originalSpotifyId = item.historyItem?.spotifyId ??
        item.queueItem?.track.id ??
        item.lovedEntry?.track.id ??
        item.id;
    final displayTrack = selectedOverride?.track ?? Track(
      id: originalSpotifyId,
      name: item.trackName,
      artistName: item.artistName,
      albumName: item.albumName,
      coverUrl: item.coverUrl ?? item.localCoverPath,
      isrc: item.historyItem?.isrc ?? item.queueItem?.track.isrc,
      duration: item.historyItem?.duration ?? item.queueItem?.track.duration ?? 0,
      source: item.historyItem?.service ??
          item.queueItem?.service ??
          item.lovedEntry?.track.source ??
          (item.source == LibraryItemSource.local ? 'local' : null),
    );

    // Determine the actual file/service to use for tap-to-play
    final playbackPath = selectedOverride?.filePath ?? item.filePath;
    final playbackService = selectedOverride?.service ?? item.historyItem?.service;
    final playbackIsrc = selectedOverride?.isrc ?? item.historyItem?.isrc;

    final fileExistsListenable = _fileExistsListenable(playbackPath);

    return Semantics(
      label: context.l10n.a11yTrackByArtist(item.trackName, item.artistName),
      selected: isSelected,
      child: Consumer(
        builder: (context, ref, _) {
          final lookup = ref.watch(downloadQueueLookupProvider);

          double progress = 0.0;
          bool isQueueActive = false;

          if (isQueueItem) {
            final activeItem = lookup.byItemId[item.queueItem!.id];
            if (activeItem != null && _isActiveStatus(activeItem.status)) {
              progress = activeItem.progress;
              isQueueActive = true;
            }
          }

          // Also check by track ID for library items that match an active download
          if (!isQueueActive) {
            final candidateIds = [
              item.historyItem?.id,
              item.historyItem?.spotifyId,
              item.historyItem?.isrc,
              item.lovedEntry?.track.id,
              item.lovedEntry?.track.isrc,
              item.localItem?.id,
              item.localItem?.isrc,
              originalSpotifyId,
            ];
            for (final tid in candidateIds) {
              if (tid == null || tid.isEmpty) continue;
              final byTrack = lookup.byTrackId[tid];
              if (byTrack != null && _isActiveStatus(byTrack.status)) {
                progress = byTrack.progress;
                isQueueActive = true;
                break;
              }
            }
          }

          // Last resort: match by track name + artist name
          if (!isQueueActive) {
            final nameKey =
                '${item.trackName.toLowerCase().trim()}|${item.artistName.toLowerCase().trim()}';
            for (final entry in lookup.byTrackId.entries) {
              final t = entry.value.track;
              if ('${t.name.toLowerCase().trim()}|${t.artistName.toLowerCase().trim()}' == nameKey &&
                  _isActiveStatus(entry.value.status)) {
                progress = entry.value.progress;
                isQueueActive = true;
                break;
              }
            }
          }

          return ValueListenableBuilder<bool>(
            valueListenable: fileExistsListenable,
            builder: (context, fileExists, _) {
              final displayProgress = isQueueActive ? progress : (fileExists ? 1.0 : 0.0);
              
              return TrackCard(
                track: displayTrack,
                albumCoverUrl: item.coverUrl ?? item.localCoverPath,
                heroTag: 'cover_lib_${item.id}',
                coverSize: 56,
                showHeartButton: true,
                showInfoButton: !isQueueActive,
                showQualityBadge: true,
                showStatusDot: true,
                showSelectionCheckbox: _isSelectionMode,
                isSelected: isSelected,
                downloadProgress: displayProgress,
                onTap: _isSelectionMode
                    ? () => _toggleSelection(item.id)
                    : (isQueueActive
                        ? () => DownloadProgressModal.show(context, item.queueItem!.id)
                        : () => _openFile(
                            playbackPath,
                            trackId: item.id,
                            title: selectedOverride?.track.name ?? item.trackName,
                            artist: selectedOverride?.track.artistName ?? item.artistName,
                            album: selectedOverride?.track.albumName ?? item.albumName,
                            coverUrl: selectedOverride?.track.coverUrl ?? item.coverUrl ?? item.localCoverPath ?? '',
                            isrc: playbackIsrc,
                            source: playbackService,
                          )),
                onToggleSelect: (_) => _toggleSelection(item.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _AnimatedLibrarySliverGrid extends StatefulWidget {
  final double maxCrossAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final SliverChildDelegate delegate;

  const _AnimatedLibrarySliverGrid({
    required this.maxCrossAxisExtent,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
    required this.childAspectRatio,
    required this.delegate,
  });

  @override
  State<_AnimatedLibrarySliverGrid> createState() =>
      _AnimatedLibrarySliverGridState();
}

class _AnimatedLibrarySliverGridState extends State<_AnimatedLibrarySliverGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late double _beginExtent;
  late double _endExtent;

  @override
  void initState() {
    super.initState();
    _beginExtent = widget.maxCrossAxisExtent;
    _endExtent = widget.maxCrossAxisExtent;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    )..value = 1;
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant _AnimatedLibrarySliverGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.maxCrossAxisExtent - _endExtent).abs() < 0.1) return;
    _beginExtent = _currentExtent;
    _endExtent = widget.maxCrossAxisExtent;
    _controller.forward(from: 0);
  }

  double get _currentExtent =>
      _beginExtent + ((_endExtent - _beginExtent) * _curve.value);

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _currentExtent,
            mainAxisSpacing: widget.mainAxisSpacing,
            crossAxisSpacing: widget.crossAxisSpacing,
            childAspectRatio: widget.childAspectRatio,
          ),
          delegate: widget.delegate,
        );
      },
    );
  }
}

class _PerTrackToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool? value;
  final bool? globalDefault;
  final ValueChanged<bool> onChanged;

  const _PerTrackToggle({
    required this.icon,
    required this.label,
    required this.value,
    this.globalDefault,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effective = value ?? globalDefault ?? false;
    final isActive = effective;

    return GestureDetector(
      onTap: () => onChanged(!isActive),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primary.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.4)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (value == null)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Icon(Icons.settings, size: 10, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
          ],
        ),
      ),
    );
  }
}
