import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/models/settings.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/track_provider.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/providers/lyrics_provider.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/playback_provider.dart';
import 'package:bitly/services/historial/history_lookup.dart';
import 'package:bitly/providers/playback_queue_provider.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/providers/extension_provider.dart';
import 'package:bitly/providers/store_provider.dart';
import 'package:bitly/providers/library_collections_provider.dart';
import 'package:bitly/providers/recent_access_provider.dart';
import 'package:bitly/providers/explore_provider.dart';
import 'package:bitly/providers/local_library_provider.dart';
import 'package:bitly/services/historial/history_lookup.dart';
import 'package:bitly/screens/track_metadata_screen.dart';
import 'package:bitly/screens/album_screen.dart';
import 'package:bitly/screens/artist_screen.dart';

import 'package:bitly/services/biblioteca/portadas/cover_cache_manager.dart';
import 'package:bitly/services/biblioteca/portadas/downloaded_embedded_cover_resolver.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/services/historial/history_lookup.dart';
import 'package:bitly/utils/app_bar_layout.dart';
import 'package:bitly/utils/source_icons.dart';
import 'package:bitly/utils/string_utils.dart';
import 'package:bitly/screens/playlist_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:bitly/screens/downloaded_album_screen.dart';
import 'package:bitly/widgets/download_service_picker.dart';
import 'package:bitly/widgets/animation_utils.dart';
import 'package:bitly/utils/clickable_metadata.dart';
import 'package:bitly/widgets/cached_cover_image.dart';
import 'package:bitly/widgets/settings_modal.dart';
import 'package:bitly/widgets/extension_store_modal.dart';
import 'package:bitly/widgets/network_status.dart';
import 'package:bitly/widgets/track_card.dart';
import 'package:bitly/widgets/album_card.dart';
import 'package:bitly/widgets/artist_card.dart';
import 'package:bitly/widgets/playlist_card.dart';
import 'package:bitly/widgets/reactive_glass_background.dart';

part 'home_tab_helpers.dart';
part 'home_tab_widgets.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});
  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _lastSearchQuery;
  late final ProviderSubscription<TrackState> _trackStateSub;
  late final ProviderSubscription<bool> _extensionInitSub;
  late final ProviderSubscription<bool> _homeFeedExtSub;

  Timer? _liveSearchDebounce;
  bool _isLiveSearchInProgress = false;
  String? _pendingLiveSearchQuery;
  static const int _minLiveSearchChars = 3;
  static const Duration _liveSearchDelay = Duration(milliseconds: 800);

  bool _embeddedCoverRefreshScheduled = false;
  List<Extension>? _thumbnailSizesExtensionsCache;
  bool _isCsvImporting = false;

  void _setCsvImporting(bool value) {
    if (_isCsvImporting == value) return;
    if (!mounted) {
      _isCsvImporting = value;
      return;
    }
    setState(() {
      _isCsvImporting = value;
    });
  }

  Map<String, (double, double)>? _thumbnailSizesCache;
  List<Track>? _searchBucketsSourceTracks;
  _SearchResultBuckets? _searchBucketsCache;
  _SearchSortOption _searchSortOption = _SearchSortOption.defaultOrder;
  List<SearchArtist>? _sortedArtistsSource;
  _SearchSortOption? _sortedArtistsMode;
  List<SearchArtist>? _sortedArtistsCache;
  List<SearchAlbum>? _sortedAlbumsSource;
  _SearchSortOption? _sortedAlbumsMode;
  List<SearchAlbum>? _sortedAlbumsCache;
  List<SearchPlaylist>? _sortedPlaylistsSource;
  _SearchSortOption? _sortedPlaylistsMode;
  List<SearchPlaylist>? _sortedPlaylistsCache;
  List<Track>? _sortedTracksSource;
  List<int>? _sortedTrackIndexesSource;
  _SearchSortOption? _sortedTracksMode;
  List<Track>? _sortedTracksCache;
  List<int>? _sortedTrackIndexesCache;

  double _responsiveScale({
    required BuildContext context,
    double min = 0.82,
    double max = 1.08,
    double baseShortestSide = 390,
  }) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final scale = shortestSide / baseShortestSide;
    if (scale < min) return min;
    if (scale > max) return max;
    return scale;
  }

  double _effectiveTextScale(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    if (textScale < 1.0) return 1.0;
    if (textScale > 1.4) return 1.4;
    return textScale;
  }

  double _recentDownloadCoverSize(BuildContext context) {
    final scale = _responsiveScale(context: context, min: 0.82, max: 1.05);
    final textScale = _effectiveTextScale(context);
    return 100 * scale * (1 + (textScale - 1) * 0.15);
  }

  double _recentDownloadsRowHeight(BuildContext context) {
    final coverSize = _recentDownloadCoverSize(context);
    final textScale = _effectiveTextScale(context);
    return coverSize + 28 + ((textScale - 1) * 8);
  }

  double _exploreCardSize(BuildContext context) {
    final scale = _responsiveScale(context: context, min: 0.82, max: 1.08);
    final textScale = _effectiveTextScale(context);
    return 145 * scale * (1 + (textScale - 1) * 0.12);
  }

  double _exploreSectionHeight(BuildContext context) {
    final cardSize = _exploreCardSize(context);
    final textScale = _effectiveTextScale(context);
    return cardSize + 58 + ((textScale - 1) * 12);
  }

  static final Map<String, String> _titleTranslations = {
    'Trending': 'Tendencias',
    'Top Songs': 'Canciones Populares',
    'Top Trending': 'Tendencias',
    'New Releases': 'Nuevos Lanzamientos',
    'Popular': 'Popular',
    'Recommended': 'Recomendado',
    'For You': 'Para Ti',
    'Charts': 'Listas',
    'Mixes': 'Mezclas',
    'Quick Picks': 'Selección Rápida',
    'Discover': 'Descubrir',
    'Top Hits': 'Éxitos',
    'Featured': 'Destacado',
    'Recently Played': 'Reproducido Recientemente',
    'Made For You': 'Hecho Para Ti',
    'Jump Back In': 'Continúa',
    'Your Favorites': 'Tus LibraryCollectionsFavorites',
    'Latest': 'Lo Último',
    'Trending Songs': 'Canciones en Tendencia',
    'Trending Now': 'Tendencia Ahora',
    'Top 50': 'Top 50',
    'Good morning': 'Buenos días',
    'Good afternoon': 'Buenas tardes',
    'Good evening': 'Buenas noches',
    'Good night': 'Buenas noches',
    'Hey!': '¡Hola!',
    'Welcome back': 'Bienvenido de vuelta',
    'Hello': 'Hola',
    'Hi': 'Hola',
    'Popular Artists': 'Artistas Populares',
    'Popular Artist': 'Artista Popular',
    'Popular Tracks': 'Canciones Populares',
    'Popular Albums': 'Álbumes Populares',
    'Artist': 'Artista',
    'Artists': 'Artistas',
    'Songs': 'Canciones',
    'Tracks': 'Canciones',
    'Albums': 'Álbumes',
    'Playlists': 'Listas de reproducción',
    'Top Artists': 'Mejores Artistas',
    'Top Albums': 'Mejores Álbumes',
    'New Songs': 'Canciones Nuevas',
    'New Albums': 'Álbumes Nuevos',
    'Daily Mix': 'Mezcla Diaria',
    'Morning Mix': 'Mezcla Matutina',
    'Evening Mix': 'Mezcla Nocturna',
    'Workout': 'Entrenamiento',
    'Relax': 'Relajación',
    'Focus': 'Enfoque',
    'Party': 'Fiesta',
    'Romance': 'Romance',
    'Sleep': 'Dormir',
    'Travel': 'Viaje',
    'Mood': 'Estado de Ánimo',
    'Genre': 'Género',
    'Decades': 'Décadas',
    'Global': 'Global',
    'Local': 'Local',
    'Live': 'En Vivo',
    'Radio': 'Radio',
    'Podcasts': 'Podcasts',
    'Episodes': 'Episodios',
    'Downloaded': 'Descargado',
    'Favorites': 'LibraryCollectionsFavorites',
    'History': 'Historial',
    'Liked Songs': 'Canciones Favoritas',
    'Liked Albums': 'Álbumes LibraryCollectionsFavorites',
    'Liked Artists': 'Artistas LibraryCollectionsFavorites',
    'Your Library': 'Tu Biblioteca',
    'Recently Added': 'Agregado Recientemente',
    'Recently Played Songs': 'Canciones Reproducidas Recientemente',
  };

  String _localizedExploreTitle(String title) {
    return _titleTranslations[title] ?? title;
  }

  Track _exploreItemToTrack(ExploreItem item) {
    return Track(
      id: item.id,
      name: item.name,
      artistName: item.artists,
      albumName: item.albumName ?? '',
      albumId: item.albumId,
      duration: item.durationMs ~/ 1000,
      trackNumber: null,
      discNumber: null,
      totalDiscs: null,
      isrc: item.isrc,
      releaseDate: item.releaseDate,
      coverUrl: item.coverUrl,
      source: _providerIdForExploreItem(item),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);

    // Run an initial fetch check in case extensions were already initialized
    // before HomeTab was mounted (e.g. auto-installed during first setup).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchExploreIfNeeded();
    });

    _trackStateSub = ref.listenManual<TrackState>(trackProvider, (
      previous,
      next,
    ) {
      _onTrackStateChanged(previous, next);
      if (previous != null &&
          previous.isLoading &&
          !next.isLoading &&
          next.error == null) {
        _navigateToDetailIfNeeded();
      }
    });

    _extensionInitSub = ref.listenManual<bool>(
      extensionProvider.select((s) => s.isInitialized),
      (previous, next) {
        if (next == true && previous != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fetchExploreIfNeeded();
          });
        }
      },
    );

    // Watch for new homeFeed extension being installed/enabled after init
    _homeFeedExtSub = ref.listenManual<bool>(
      extensionProvider.select(
        (s) => s.extensions.any((e) => e.enabled && e.hasHomeFeed),
      ),
      (previous, next) {
        if (next == true && previous != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref
                  .read(exploreProvider.notifier)
                  .fetchHomeFeed(forceRefresh: true);
            }
          });
        }
      },
    );
  }

  void _fetchExploreIfNeeded() {
    if (ref.read(settingsProvider).homeFeedProvider ==
        AppSettings.homeFeedProviderOff) {
      ref.read(exploreProvider.notifier).clear();
      return;
    }

    final extState = ref.read(extensionProvider);
    final exploreState = ref.read(exploreProvider);
    final hasHomeFeedExtension = extState.extensions.any(
      (e) => e.enabled && e.hasHomeFeed,
    );
    if (hasHomeFeedExtension &&
        !exploreState.hasContent &&
        !exploreState.isLoading) {
      ref.read(exploreProvider.notifier).fetchHomeFeed();
    }
  }

  @override
  void dispose() {
    _liveSearchDebounce?.cancel();
    _trackStateSub.close();
    _extensionInitSub.close();
    _homeFeedExtSub.close();
    _urlController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _urlController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Map<String, (double, double)> _getThumbnailSizesByExtensionId(
    List<Extension> extensions,
  ) {
    final cached = _thumbnailSizesCache;
    if (cached != null &&
        identical(extensions, _thumbnailSizesExtensionsCache)) {
      return cached;
    }

    final map = <String, (double, double)>{
      for (final extension in extensions)
        if (extension.searchBehavior != null)
          extension.id: extension.searchBehavior!.getThumbnailSize(
            defaultSize: 56,
          ),
    };
    _thumbnailSizesExtensionsCache = extensions;
    _thumbnailSizesCache = map;
    return map;
  }

  List<SearchFilter> _resolveSearchFilters(
    BuildContext context,
    String? currentSearchProvider,
    List<Extension> extensions,
  ) {
    final resolvedSearchProvider = _resolveSearchProvider(
      currentSearchProvider,
      extensions,
    );
    final isUsingExtensionSearch =
        resolvedSearchProvider != null &&
        resolvedSearchProvider.isNotEmpty &&
        extensions.any((e) => e.id == resolvedSearchProvider && e.enabled);

    if (isUsingExtensionSearch) {
      final currentSearchExtension = extensions
          .where((e) => e.id == resolvedSearchProvider && e.enabled)
          .firstOrNull;
      final filters = currentSearchExtension?.searchBehavior?.filters;
      if (filters != null && filters.isNotEmpty) {
        return filters
            .map(
              (f) => SearchFilter(
                id: f.id,
                label: _localizedExploreTitle(f.label ?? f.id),
                icon: f.icon,
              ),
            )
            .toList();
      }
    }

    return [
      SearchFilter(id: 'track', label: context.l10n.searchSongs, icon: 'music'),
      SearchFilter(
        id: 'artist',
        label: context.l10n.searchArtists,
        icon: 'artist',
      ),
      SearchFilter(
        id: 'album',
        label: context.l10n.searchAlbums,
        icon: 'album',
      ),
      SearchFilter(
        id: 'playlist',
        label: context.l10n.searchPlaylists,
        icon: 'playlist',
      ),
    ];
  }

  Extension? _defaultSearchExtension(List<Extension> extensions) {
    return extensions
            .where(
              (ext) =>
                  ext.enabled &&
                  ext.hasCustomSearch &&
                  ext.searchBehavior?.primary == true,
            )
            .firstOrNull ??
        extensions
            .where((ext) => ext.enabled && ext.hasCustomSearch)
            .firstOrNull;
  }

  String? _resolveSearchProvider(
    String? explicitSearchProvider,
    List<Extension> extensions,
  ) {
    final explicit = explicitSearchProvider?.trim();
    if (explicit != null &&
        explicit.isNotEmpty &&
        extensions.any(
          (ext) => ext.enabled && ext.hasCustomSearch && ext.id == explicit,
        )) {
      return explicit;
    }
    return _defaultSearchExtension(extensions)?.id;
  }

  bool _hasSearchProvider(
    String? explicitSearchProvider,
    List<Extension> extensions,
  ) {
    final explicit = explicitSearchProvider?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      if (extensions.any(
        (ext) => ext.enabled && ext.hasCustomSearch && ext.id == explicit,
      )) {
        return true;
      }
    }

    if (extensions.any((ext) => ext.enabled && ext.hasCustomSearch)) {
      return true;
    }

    return PlatformBridge.supportsCoreBackend;
  }

  String? _sanitizeSearchFilterForProvider(
    String? filter,
    String? currentSearchProvider,
    List<Extension> extensions,
  ) {
    if (filter == null || filter.isEmpty) {
      return null;
    }

    final canonicalFilter = _canonicalSearchFilterId(filter);

    if (currentSearchProvider == null || currentSearchProvider.isEmpty) {
      switch (canonicalFilter) {
        case 'track':
        case 'artist':
        case 'album':
        case 'playlist':
          return canonicalFilter;
        default:
          return null;
      }
    }

    final extension = extensions
        .where((e) => e.id == currentSearchProvider && e.enabled)
        .firstOrNull;
    final filters = extension?.searchBehavior?.filters;
    if (filters == null || filters.isEmpty) {
      return null;
    }

    final match = filters
        .where(
          (candidate) =>
              _canonicalSearchFilterId(candidate.id) == canonicalFilter ||
              (candidate.label != null &&
                  _canonicalSearchFilterId(candidate.label!) ==
                      canonicalFilter) ||
              (candidate.icon != null &&
                  _canonicalSearchFilterId(candidate.icon!) == canonicalFilter),
        )
        .firstOrNull;
    return match?.id;
  }

  String _canonicalSearchFilterId(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '',
    );
    switch (normalized) {
      case 'track':
      case 'tracks':
      case 'song':
      case 'songs':
      case 'music':
        return 'track';
      case 'artist':
      case 'artists':
        return 'artist';
      case 'album':
      case 'albums':
        return 'album';
      case 'playlist':
      case 'playlists':
        return 'playlist';
      default:
        return normalized;
    }
  }

  String? _preferredSearchFilter(
    String preferredSearchTab,
    String? currentSearchProvider,
    List<Extension> extensions,
  ) {
    final preferred = switch (preferredSearchTab) {
      'track' => 'track',
      'artist' => 'artist',
      'album' => 'album',
      'playlist' => 'playlist',
      _ => null,
    };

    return _sanitizeSearchFilterForProvider(
      preferred,
      currentSearchProvider,
      extensions,
    );
  }

  String _displaySearchFilterSelection(
    String? selectedSearchFilter,
    String preferredSearchTab,
    String? currentSearchProvider,
    List<Extension> extensions,
  ) {
    if (selectedSearchFilter == 'all') {
      return 'all';
    }
    if (selectedSearchFilter != null && selectedSearchFilter.isNotEmpty) {
      return _sanitizeSearchFilterForProvider(
            selectedSearchFilter,
            currentSearchProvider,
            extensions,
          ) ??
          'all';
    }
    return _preferredSearchFilter(
          preferredSearchTab,
          currentSearchProvider,
          extensions,
        ) ??
        'all';
  }

  _SearchResultBuckets _getSearchResultBuckets(List<Track> tracks) {
    final cached = _searchBucketsCache;
    if (cached != null && identical(tracks, _searchBucketsSourceTracks)) {
      return cached;
    }

    final realTracks = <Track>[];
    final realTrackIndexes = <int>[];
    final albumItems = <Track>[];
    final playlistItems = <Track>[];
    final artistItems = <Track>[];

    // Deduplication map: "name|artist" -> List of tracks
    // Also deduplicates by normalized source within each group
    final groupedTracks = <String, List<(Track, int)>>{};

    for (int i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      if (!track.isCollection) {
        final key = track.identityKey;
        groupedTracks.putIfAbsent(key, () => []).add((track, i));
      }
      if (track.isAlbumItem) {
        albumItems.add(track);
      }
      if (track.isPlaylistItem) {
        playlistItems.add(track);
      }
      if (track.isArtistItem) {
        final dedupKey =
            '${normalizeForMatch(track.artistName)}|${normalizeSource(track.source)}';
        if (!artistItems.any(
          (a) =>
              '${normalizeForMatch(a.artistName)}|${normalizeSource(a.source)}' ==
              dedupKey,
        )) {
          artistItems.add(track);
        }
      }
    }

    // Process grouped tracks to create master tracks with alternates.
    // Every unique normalized source gets its own entry in alternateSources
    // so the user can switch between them on the same card.
    for (final group in groupedTracks.values) {
      if (group.isEmpty) continue;

      // Use the first track in the group as the master
      final primary = group[0].$1;
      final primaryIndex = group[0].$2;

      if (group.length > 1) {
        final seenSources = <String>{};
        final allSources = <Track>[];
        for (final entry in group) {
          final t = entry.$1;
          final norm = normalizeSource(t.source);
          if (seenSources.add(norm)) {
            allSources.add(t);
          }
        }
        realTracks.add(primary.copyWith(alternateSources: allSources));
      } else {
        realTracks.add(primary);
      }
      realTrackIndexes.add(primaryIndex);
    }

    final buckets = _SearchResultBuckets(
      realTracks: realTracks,
      realTrackIndexes: realTrackIndexes,
      albumItems: albumItems,
      playlistItems: playlistItems,
      artistItems: artistItems,
    );
    _searchBucketsSourceTracks = tracks;
    _searchBucketsCache = buckets;
    return buckets;
  }

  void _invalidateSearchSortCaches() {
    _sortedArtistsSource = null;
    _sortedArtistsMode = null;
    _sortedArtistsCache = null;
    _sortedAlbumsSource = null;
    _sortedAlbumsMode = null;
    _sortedAlbumsCache = null;
    _sortedPlaylistsSource = null;
    _sortedPlaylistsMode = null;
    _sortedPlaylistsCache = null;
    _sortedTracksSource = null;
    _sortedTrackIndexesSource = null;
    _sortedTracksMode = null;
    _sortedTracksCache = null;
    _sortedTrackIndexesCache = null;
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() {});
    }
    if (_searchFocusNode.hasFocus) {
      ref.read(trackProvider.notifier).setShowingRecentAccess(true);
    }
  }

  void _onTrackStateChanged(TrackState? previous, TrackState next) {
    if (previous != null &&
        !next.hasContent &&
        !next.hasSearchText &&
        !next.isLoading &&
        _urlController.text.isNotEmpty &&
        !_searchFocusNode.hasFocus) {
      _urlController.clear();
    }
  }

  bool _isLiveSearchEnabled() {
    final settings = ref.read(settingsProvider);
    final extState = ref.read(extensionProvider);
    if (!extState.isInitialized && extState.error == null) return true;

    final searchProvider = _resolveSearchProvider(
      settings.searchProvider,
      extState.extensions,
    );

    if (searchProvider == null || searchProvider.isEmpty) return false;

    final extension = extState.extensions
        .where((e) => e.id == searchProvider && e.enabled)
        .firstOrNull;
    return extension != null;
  }

  void _onSearchChanged() {
    final text = _urlController.text.trim();

    ref.read(trackProvider.notifier).setSearchText(text.isNotEmpty);

    if (text.isEmpty) {
      _liveSearchDebounce?.cancel();
      return;
    }

    if (_isLiveSearchEnabled() && text.length >= _minLiveSearchChars) {
      if (text.startsWith('http') || text.startsWith('spotify:')) return;

      _liveSearchDebounce?.cancel();
      _liveSearchDebounce = Timer(_liveSearchDelay, () {
        if (mounted && _urlController.text.trim() == text) {
          _executeLiveSearch(text);
        }
      });
    }
  }

  Future<void> _executeLiveSearch(String query) async {
    if (_isLiveSearchInProgress) {
      _pendingLiveSearchQuery = query;
      return;
    }

    _isLiveSearchInProgress = true;
    _pendingLiveSearchQuery = null;

    try {
      await _performSearch(query);
    } finally {
      _isLiveSearchInProgress = false;

      final pending = _pendingLiveSearchQuery;
      _pendingLiveSearchQuery = null;

      if (pending != null &&
          pending != query &&
          mounted &&
          _urlController.text.trim() == pending) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (mounted && _urlController.text.trim() == pending) {
          _executeLiveSearch(pending);
        }
      }
    }
  }

  Future<void> _performSearch(String query, {String? filterOverride}) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline =
        connectivityResult.contains(ConnectivityResult.none) ||
        (!connectivityResult.contains(ConnectivityResult.wifi) &&
            !connectivityResult.contains(ConnectivityResult.mobile));

    if (isOffline) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conéctate a Wi-Fi o datos móviles para buscar'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    var extState = ref.read(extensionProvider);
    if (!extState.isInitialized && extState.error == null) {
      await ref.read(extensionProvider.notifier).waitForInitialization();
      extState = ref.read(extensionProvider);
    }

    final settings = ref.read(settingsProvider);
    final searchProvider = _resolveSearchProvider(
      settings.searchProvider,
      extState.extensions,
    );
    final storedFilter = ref.read(trackProvider).selectedSearchFilter;
    final selectedFilter = switch (filterOverride) {
      'all' => null,
      final explicit? => _sanitizeSearchFilterForProvider(
        explicit,
        searchProvider,
        extState.extensions,
      ),
      null => switch (storedFilter) {
        'all' => null,
        final stored? => _sanitizeSearchFilterForProvider(
          stored,
          searchProvider,
          extState.extensions,
        ),
        null => _preferredSearchFilter(
          settings.defaultSearchTab,
          searchProvider,
          extState.extensions,
        ),
      },
    };

    final searchKey =
        '${searchProvider ?? 'default'}:$query:${selectedFilter ?? 'all'}';
    if (_lastSearchQuery == searchKey) return;
    _lastSearchQuery = searchKey;
    _searchSortOption = _SearchSortOption.defaultOrder;
    _invalidateSearchSortCaches();

    final isExtensionEnabled =
        searchProvider != null &&
        searchProvider.isNotEmpty &&
        extState.extensions.any((e) => e.id == searchProvider && e.enabled);

    if (isExtensionEnabled) {
      Map<String, dynamic>? options;
      if (selectedFilter != null) {
        options = {'filter': selectedFilter};
      }
      await ref
          .read(trackProvider.notifier)
          .customSearch(
            searchProvider,
            query,
            options: options,
            selectedFilter: selectedFilter,
          );
    } else {
      if (searchProvider != null &&
          searchProvider.isNotEmpty &&
          !isExtensionEnabled) {
        ref.read(settingsProvider.notifier).setSearchProvider(null);
      }
      await ref
          .read(trackProvider.notifier)
          .search(query, filterOverride: selectedFilter);
    }
    ref.read(settingsProvider.notifier).setHasSearchedBefore();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
      final text = data.text!.trim();
      if (text.startsWith('http') || text.startsWith('spotify:')) {
        _fetchMetadata();
      }
    }
  }

  Future<void> _clearAndRefresh() async {
    _liveSearchDebounce?.cancel();
    _pendingLiveSearchQuery = null;
    _urlController.clear();
    _searchFocusNode.unfocus();
    _lastSearchQuery = null;
    ref.read(trackProvider.notifier).clear();
  }

  Future<void> _fetchMetadata() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (url.startsWith('http') || url.startsWith('spotify:')) {
      await ref.read(trackProvider.notifier).fetchFromUrl(url);
      final trackState = ref.read(trackProvider);
      if (trackState.error != null && mounted) {
        final l10n = context.l10n;
        final errorMsg = trackState.error!;
        final isRateLimit =
            errorMsg.contains('429') ||
            errorMsg.toLowerCase().contains('rate limit') ||
            errorMsg.toLowerCase().contains('too many requests');
        final displayMessage = errorMsg == 'url_not_recognized'
            ? l10n.errorUrlNotRecognizedMessage
            : isRateLimit
            ? l10n.errorRateLimitedMessage
            : l10n.errorUrlFetchFailed;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(displayMessage)));
        ref.read(trackProvider.notifier).clear();
      } else {
        _navigateToDetailIfNeeded();
      }
    } else {
      await ref.read(trackProvider.notifier).search(url);
    }
    ref.read(settingsProvider.notifier).setHasSearchedBefore();
  }

  void _navigateToDetailIfNeeded() {
    final trackState = ref.read(trackProvider);

    if (trackState.albumId != null &&
        trackState.albumName != null &&
        trackState.tracks.isNotEmpty) {
      final extensionId = trackState.searchExtensionId;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => AlbumScreen(
            albumId: trackState.albumId!,
            albumName: trackState.albumName!,
            coverUrl: trackState.coverUrl,
            tracks: trackState.tracks,
            extensionId: extensionId,
          ),
        ),
      );
      ref.read(trackProvider.notifier).clear();
      _urlController.clear();
      return;
    }

    if (trackState.playlistName != null && trackState.tracks.isNotEmpty) {
      ref
          .read(recentAccessProvider.notifier)
          .recordPlaylistAccess(
            id: trackState.playlistName!,
            name: trackState.playlistName!,
            imageUrl: trackState.coverUrl,
            providerId: trackState.searchExtensionId ?? 'spotify',
          );

      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => PlaylistScreen(
            playlistName: trackState.playlistName!,
            coverUrl: trackState.coverUrl,
            tracks: trackState.tracks,
            recommendedService:
                trackState.searchExtensionId ?? trackState.searchSource,
          ),
        ),
      );
      ref.read(trackProvider.notifier).clear();
      _urlController.clear();
      return;
    }

    if (trackState.artistId != null &&
        trackState.artistName != null &&
        trackState.artistAlbums != null) {
      final extensionId = trackState.searchExtensionId;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => ArtistScreen(
            artistId: trackState.artistId!,
            artistName: trackState.artistName!,
            coverUrl: trackState.coverUrl,
            albums: trackState.artistAlbums!,
            extensionId: extensionId,
          ),
        ),
      );
      ref.read(trackProvider.notifier).clear();
      _urlController.clear();
      return;
    }
  }

  void _downloadTrack(int index) {
    final trackState = ref.read(trackProvider);
    if (index >= 0 && index < trackState.tracks.length) {
      final track = trackState.tracks[index];
      final settings = ref.read(settingsProvider);

      if (!settings.isPremium && settings.premiumUntil == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suscríbete a premium para descargar')),
        );
        return;
      }

      if (settings.askQualityBeforeDownload) {
        DownloadServicePicker.show(
          context,
          trackName: track.name,
          artistName: track.artistName,
          coverUrl: track.coverUrl,
          recommendedService:
              trackState.searchExtensionId ?? trackState.searchSource,
          onSelect: (quality, service) {
            ref
                .read(downloadQueueProvider.notifier)
                .addToQueue(track, service, qualityOverride: quality);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.snackbarAddedToQueue(track.name)),
              ),
            );
          },
        );
      } else {
        final extensionState = ref.read(extensionProvider);
        final service = resolveEffectiveDownloadService(
          settings.defaultService,
          extensionState,
        );
        if (service.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.extensionsNoDownloadProvider)),
          );
          return;
        }
        ref.read(downloadQueueProvider.notifier).addToQueue(track, service);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.snackbarAddedToQueue(track.name)),
          ),
        );
      }
    }
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    if (!settings.isPremium && settings.premiumUntil == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suscríbete a premium para importar playlists'),
        ),
      );
      return;
    }
    if (_isCsvImporting) return;
    _setCsvImporting(true);

    int currentProgress = 0;
    int totalTracks = 0;

    bool progressDialogInitialized = false;
    bool progressDialogVisible = false;
    BuildContext? progressDialogContext;
    StateSetter? setDialogState;

    void showProgressDialog() {
      if (progressDialogInitialized || !mounted) return;
      progressDialogInitialized = true;
      progressDialogVisible = true;
      showDialog<void>(
        context: this.context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (dialogCtx, setState) {
            progressDialogContext = dialogCtx;
            setDialogState = setState;
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    totalTracks > 0
                        ? context.l10n.progressFetchingMetadata(
                            currentProgress,
                            totalTracks,
                          )
                        : context.l10n.progressReadingCsv,
                  ),
                ],
              ),
            );
          },
        ),
      ).then((_) {
        progressDialogVisible = false;
        progressDialogContext = null;
      });
    }

    void closeProgressDialog() {
      if (!progressDialogVisible) return;
      setDialogState = null;
      try {
        if (progressDialogContext != null) {
          Navigator.of(progressDialogContext!).pop();
        } else if (mounted) {
          final navigator = Navigator.of(this.context);
          if (navigator.canPop()) {
            navigator.pop();
          }
        }
      } catch (_) {}
      progressDialogVisible = false;
      progressDialogContext = null;
    }

    try {
      // CSV import functionality removed
    } finally {
      closeProgressDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final hasActualResults = ref.watch(
      trackProvider.select(
        (s) =>
            s.tracks.isNotEmpty ||
            (s.searchArtists != null && s.searchArtists!.isNotEmpty) ||
            (s.searchAlbums != null && s.searchAlbums!.isNotEmpty) ||
            (s.searchPlaylists != null && s.searchPlaylists!.isNotEmpty),
      ),
    );
    final isLoading = ref.watch(trackProvider.select((s) => s.isLoading));
    final hasSearchedBefore = ref.watch(
      settingsProvider.select((s) => s.hasSearchedBefore),
    );
    final explicitSearchProvider = ref.watch(
      settingsProvider.select((s) => s.searchProvider),
    );
    final defaultSearchTab = ref.watch(
      settingsProvider.select((s) => s.defaultSearchTab),
    );
    final extensions = ref.watch(extensionProvider.select((s) => s.extensions));
    final extensionReadiness = ref.watch(
      extensionProvider.select(
        (s) => (isInitialized: s.isInitialized, error: s.error),
      ),
    );

    final hasExploreContent = ref.watch(
      exploreProvider.select((s) => s.sections.isNotEmpty),
    );
    final exploreLoading = ref.watch(
      exploreProvider.select((s) => s.isLoading),
    );
    final hasHomeFeedExtension = ref.watch(
      extensionProvider.select(
        (s) => s.extensions.any((e) => e.enabled && e.hasHomeFeed),
      ),
    );
    final homeFeedDisabled = ref.watch(
      settingsProvider.select(
        (s) => s.homeFeedProvider == AppSettings.homeFeedProviderOff,
      ),
    );

    final colorScheme = Theme.of(context).colorScheme;
    final currentCover = ref.watch(
      playbackQueueProvider.select(
        (q) => q.currentIndex >= 0 && q.currentIndex < q.items.length
            ? q.items[q.currentIndex].track.coverUrl
            : null,
      ),
    );
    final searchText = _urlController.text.trim();
    final hasSearchInput = searchText.isNotEmpty;
    final isSearchFocused = _searchFocusNode.hasFocus;
    final hasShortSearchInput =
        hasSearchInput && searchText.length < _minLiveSearchChars;
    final isShowingRecentAccess = ref.watch(
      trackProvider.select((s) => s.isShowingRecentAccess),
    );
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = normalizedHeaderTopPadding(context);
    final hasHistoryItems = ref.watch(
      _homeHistoryPreviewProvider.select((items) => items.isNotEmpty),
    );

    final recentModeRequested = isShowingRecentAccess || isSearchFocused;
    final showRecentAccess =
        recentModeRequested &&
        (!hasSearchInput || hasShortSearchInput || !hasActualResults) &&
        !isLoading;
    final isSearchProviderLoading =
        !extensionReadiness.isInitialized && extensionReadiness.error == null;
    final hasSearchProvider = _hasSearchProvider(
      explicitSearchProvider,
      extensions,
    );
    final showSearchBar = hasSearchProvider || isSearchProviderLoading;
    final hasResults =
        hasSearchInput || hasActualResults || isLoading || showRecentAccess;
    final showExplore =
        !hasActualResults &&
        !isLoading &&
        !showRecentAccess &&
        !homeFeedDisabled &&
        (hasHomeFeedExtension || hasExploreContent) &&
        hasExploreContent;
    final showEmptyHomeState =
        !isSearchProviderLoading &&
        !hasSearchProvider &&
        !hasSearchInput &&
        !hasHomeFeedExtension &&
        !hasExploreContent;

    ref.listen<String>(settingsProvider.select((s) => s.defaultSearchTab), (
      previous,
      next,
    ) {
      if (previous == next) return;
      final selectedSearchFilter = ref.read(
        trackProvider.select((s) => s.selectedSearchFilter),
      );
      if (selectedSearchFilter != null && selectedSearchFilter.isNotEmpty) {
        return;
      }

      final text = _urlController.text.trim();
      if (text.isEmpty || text.length < _minLiveSearchChars) return;
      if (text.startsWith('http') || text.startsWith('spotify:')) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _lastSearchQuery = null;
        _performSearch(text);
      });
    });

    if (hasActualResults &&
        isShowingRecentAccess &&
        hasSearchInput &&
        !isSearchFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(trackProvider.notifier).setShowingRecentAccess(false);
        }
      });
    }

    return GestureDetector(
      onTap: () {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: ReactiveGlassBackground(child: SizedBox.expand()),
            ),
            RefreshIndicator(
              onRefresh: () => ref.read(exploreProvider.notifier).refresh(),
              notificationPredicate: (notification) => showExplore,
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverAppBar(
                    expandedHeight: 120 + topPadding,
                    collapsedHeight: kToolbarHeight,
                    floating: false,
                    pinned: true,
                    backgroundColor: colorScheme.surface.withValues(alpha: 0.5),
                    surfaceTintColor: Colors.transparent,
                    automaticallyImplyLeading: false,
                    actions: [
                      Consumer(
                        builder: (context, ref, _) {
                          final extState = ref.watch(extensionProvider);
                          final storeState = ref.watch(storeProvider);
                          final hasExtensions = extState.extensions.isNotEmpty;
                          final updatesCount = storeState.updatesAvailableCount;
                          return Badge(
                            isLabelVisible: !hasExtensions || updatesCount > 0,
                            label: Text(!hasExtensions ? '!' : '$updatesCount'),
                            backgroundColor: !hasExtensions
                                ? colorScheme.error
                                : null,
                            child: IconButton(
                              icon: Icon(
                                hasExtensions
                                    ? Icons.dns_outlined
                                    : Icons.dns_outlined,
                                color: hasExtensions
                                    ? colorScheme.onSurface
                                    : colorScheme.error,
                              ),
                              tooltip: 'Extensiones',
                              onPressed: () =>
                                  showExtensionStoreModal(context, ref),
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: context.l10n.settingsTitle,
                          onPressed: () => showSettingsModal(context),
                        ),
                      ),
                      const NetworkStatusIcon(),
                    ],
                    flexibleSpace: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxHeight = 120 + topPadding;
                        final minHeight = kToolbarHeight + topPadding;
                        final expandRatio =
                            ((constraints.maxHeight - minHeight) /
                                    (maxHeight - minHeight))
                                .clamp(0.0, 1.0);

                        return FlexibleSpaceBar(
                          expandedTitleScale: 1.0,
                          titlePadding: const EdgeInsets.only(
                            left: 24,
                            bottom: 16,
                          ),
                          title: Text(
                            context.l10n.homeTitle,
                            style: TextStyle(
                              fontSize: 20 + (14 * expandRatio),
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: (hasResults || showExplore)
                          ? const SizedBox.shrink()
                          : _buildHomeIntro(
                              colorScheme: colorScheme,
                              screenHeight: screenHeight,
                              showEmptyHomeState: showEmptyHomeState,
                            ),
                    ),
                  ),

                  if (showSearchBar)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          (hasResults || showExplore) ? 8 : 32,
                          16,
                          (hasResults || showExplore) ? 8 : 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _UsernamePrompt(colorScheme: colorScheme),
                            const SizedBox(height: 12),
                            _buildSearchBar(colorScheme),
                          ],
                        ),
                      ),
                    ),

                  if (hasActualResults && !showRecentAccess)
                    Consumer(
                      builder: (context, ref, _) {
                        final currentSearchProvider = ref.watch(
                          settingsProvider.select((s) => s.searchProvider),
                        );
                        final extensions = ref.watch(
                          extensionProvider.select((s) => s.extensions),
                        );
                        final selectedSearchFilter = ref.watch(
                          trackProvider.select((s) => s.selectedSearchFilter),
                        );
                        final searchFilters = _resolveSearchFilters(
                          context,
                          currentSearchProvider,
                          extensions,
                        );
                        if (searchFilters.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: SizedBox.shrink(),
                          );
                        }
                        return SliverToBoxAdapter(
                          child: _buildSearchFilterBar(
                            searchFilters,
                            _displaySearchFilterSelection(
                              selectedSearchFilter,
                              defaultSearchTab,
                              currentSearchProvider,
                              extensions,
                            ),
                            colorScheme,
                          ),
                        );
                      },
                    ),

                  if (showRecentAccess)
                    Consumer(
                      builder: (context, ref, _) {
                        final recentAccessView = ref.watch(
                          recentAccessViewProvider,
                        );
                        return SliverToBoxAdapter(
                          child: _buildRecentAccess(
                            recentAccessView,
                            colorScheme,
                          ),
                        );
                      },
                    ),

                  SliverToBoxAdapter(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child:
                          (hasResults ||
                              showRecentAccess ||
                              showExplore ||
                              showEmptyHomeState)
                          ? const SizedBox.shrink()
                          : Column(
                              children: [
                                if (!hasSearchedBefore)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      context.l10n.homeSupports,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                if (hasHistoryItems)
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final historyItems = ref.watch(
                                        _homeHistoryPreviewProvider,
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          32,
                                          24,
                                          24,
                                        ),
                                        child: _buildRecentDownloads(
                                          historyItems,
                                          colorScheme,
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                    ),
                  ),

                  if (showExplore)
                    Consumer(
                      builder: (context, ref, _) {
                        final exploreSections = ref.watch(
                          exploreProvider.select((s) => s.sections),
                        );
                        final exploreGreeting = ref.watch(
                          exploreProvider.select((s) => s.greeting),
                        );
                        return SliverMainAxisGroup(
                          slivers: _buildExploreSections(
                            exploreSections,
                            exploreGreeting,
                            colorScheme,
                          ),
                        );
                      },
                    ),

                  if (hasHomeFeedExtension &&
                      !homeFeedDisabled &&
                      !hasActualResults &&
                      !isLoading &&
                      exploreLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: TrackListSkeleton(itemCount: 5),
                      ),
                    ),

                  Consumer(
                    builder: (context, ref, _) {
                      final tracks = ref.watch(
                        trackProvider.select((s) => s.tracks),
                      );
                      final searchArtists = ref.watch(
                        trackProvider.select((s) => s.searchArtists),
                      );
                      final searchAlbums = ref.watch(
                        trackProvider.select((s) => s.searchAlbums),
                      );
                      final searchPlaylists = ref.watch(
                        trackProvider.select((s) => s.searchPlaylists),
                      );
                      final isLoading = ref.watch(
                        trackProvider.select((s) => s.isLoading),
                      );
                      final error = ref.watch(
                        trackProvider.select((s) => s.error),
                      );
                      final searchExtensionId = ref.watch(
                        trackProvider.select((s) => s.searchExtensionId),
                      );
                      final localLibrarySettings = ref.watch(
                        settingsProvider.select(
                          (s) => (
                            s.localLibraryEnabled,
                            s.localLibraryShowDuplicates,
                          ),
                        ),
                      );
                      final extensions = ref.watch(
                        extensionProvider.select((s) => s.extensions),
                      );
                      final showLocalLibraryIndicator =
                          localLibrarySettings.$1 && localLibrarySettings.$2;
                      final thumbnailSizesByExtensionId =
                          _getThumbnailSizesByExtensionId(extensions);
                      final hasResults =
                          tracks.isNotEmpty ||
                          (searchArtists != null && searchArtists.isNotEmpty) ||
                          (searchAlbums != null && searchAlbums.isNotEmpty) ||
                          (searchPlaylists != null &&
                              searchPlaylists.isNotEmpty) ||
                          isLoading ||
                          error != null;

                      return SliverMainAxisGroup(
                        slivers: _buildSearchResults(
                          tracks: tracks,
                          searchArtists: searchArtists,
                          searchAlbums: searchAlbums,
                          searchPlaylists: searchPlaylists,
                          isLoading: isLoading,
                          error: error,
                          colorScheme: colorScheme,
                          hasResults: hasResults,
                          searchExtensionId: searchExtensionId,
                          showLocalLibraryIndicator: showLocalLibraryIndicator,
                          thumbnailSizesByExtensionId:
                              thumbnailSizesByExtensionId,
                        ),
                      );
                    },
                  ),
            ],
          ),
        ),
      ],
    ),
  ),
    );
  }

  Widget _GlassHomeBackground({
    required String? coverUrl,
    required ColorScheme colorScheme,
  }) {
    Widget? coverWidget;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('http://') || coverUrl.startsWith('https://')) {
        coverWidget = CachedNetworkImage(
          imageUrl: coverUrl,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          cacheManager: CoverCacheManager.instance,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        );
      } else {
        coverWidget = Image.file(
          File(coverUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }
    return RepaintBoundary(
      child: Stack(
        children: [
          if (coverWidget != null) Positioned.fill(child: coverWidget),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned.fill(
            child: Container(color: colorScheme.surface.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeIntro({
    required ColorScheme colorScheme,
    required double screenHeight,
    required bool showEmptyHomeState,
  }) {
    if (showEmptyHomeState) {
      final emptyHeight = (screenHeight - 220).clamp(280.0, 520.0).toDouble();
      return SizedBox(
        height: emptyHeight,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.extension_outlined,
                  size: 56,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.homeEmptyTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.homeEmptySubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(height: screenHeight * 0.06),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/logo-transparant.png',
              color: colorScheme.onPrimary,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bitly',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.homeSubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _onEmbeddedCoverChanged() {
    if (!mounted || _embeddedCoverRefreshScheduled) return;
    _embeddedCoverRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _embeddedCoverRefreshScheduled = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  Widget _buildRecentDownloads(
    List<DownloadHistoryItem> items,
    ColorScheme colorScheme,
  ) {
    final itemCount = items.length < 10 ? items.length : 10;
    final coverSize = _recentDownloadCoverSize(context);
    final rowHeight = _recentDownloadsRowHeight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            context.l10n.homeRecent,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          height: rowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final item = items[index];
              return KeyedSubtree(
                key: ValueKey(item.id),
                child: Semantics(
                  button: true,
                  label: context.l10n.a11yOpenTrackByArtist(
                    item.trackName,
                    item.artistName,
                  ),
                  child: GestureDetector(
                    onTap: () => _navigateToMetadataScreen(
                      item,
                      navigationItems: items
                          .take(itemCount)
                          .toList(growable: false),
                      navigationIndex: index,
                    ),
                    child: Container(
                      width: coverSize,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          _DownloadedOrRemoteCover(
                            downloadedFilePath: item.filePath,
                            imageUrl: item.coverUrl,
                            width: coverSize,
                            height: coverSize,
                            borderRadius: BorderRadius.circular(12),
                            fallbackIcon: Icons.music_note,
                            fallbackIconSize: 32,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.trackName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildExploreSections(
    List<ExploreSection> sections,
    String? greeting,
    ColorScheme colorScheme,
  ) {
    final hasGreeting = greeting != null && greeting.isNotEmpty;
    final sectionOffset = hasGreeting ? 1 : 0;
    final totalCount = sections.length + sectionOffset + 1;

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (hasGreeting && index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                _localizedExploreTitle(greeting),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          final sectionIndex = index - sectionOffset;
          if (sectionIndex < sections.length) {
            final section = sections[sectionIndex];
            return KeyedSubtree(
              key: ValueKey('explore-section-${section.uri}-${section.title}'),
              child: _buildExploreSection(section, colorScheme),
            );
          }

          return const SizedBox(height: 24);
        }, childCount: totalCount),
      ),
    ];
  }

  Widget _buildExploreSection(ExploreSection section, ColorScheme colorScheme) {
    final sectionHeight = _exploreSectionHeight(context);
    if (section.isYTMusicQuickPicks) {
      return _buildYTMusicQuickPicksSection(section, colorScheme);
    }

    final localizedTitle = _localizedExploreTitle(section.title);

    if (section.items.every((item) => item.type == 'track')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              localizedTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...section.items.map((item) {
            final track = _exploreItemToTrack(item);
            return Consumer(
              builder: (context, ref, _) {
                final queueItem = ref.watch(
                  downloadQueueLookupProvider.select(
                    (lookup) => lookup.byTrackId[track.id],
                  ),
                );
                final isInHistory = ref
                    .watch(
                      downloadHistoryExistsProvider(
                        historyLookupForTrack(track),
                      ),
                    )
                    .maybeWhen(data: (exists) => exists, orElse: () => false);
                final isInLocal = ref.watch(
                  localLibraryProvider.select(
                    (s) => s.existsInLibrary(
                      isrc: track.isrc,
                      trackName: track.name,
                      artistName: track.artistName,
                    ),
                  ),
                );
                final isQueued = queueItem != null;
                final hasLocal = isInHistory || isInLocal;
                final progress = isQueued ? 0.5 : (hasLocal ? 1.0 : 0.0);
                return TrackCard(
                  track: track,
                  downloadProgress: progress,
                  onDownload: hasLocal
                      ? null
                      : () => _handleExploreTrackPrimaryAction(item),
                );
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            localizedTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: sectionHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              final item = section.items[index];
              return StaggeredListItem(
                key: ValueKey(
                  'explore-item-${item.type}-${item.id}-${item.uri}',
                ),
                index: index,
                staggerDelay: const Duration(milliseconds: 50),
                child: _buildExploreItem(item, colorScheme),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYTMusicQuickPicksSection(
    ExploreSection section,
    ColorScheme colorScheme,
  ) {
    const itemsPerPage = 5;
    final totalPages = (section.items.length / itemsPerPage).ceil();
    final localizedTitle = _localizedExploreTitle(section.title);

    return _QuickPicksPageView(
      section: section,
      colorScheme: colorScheme,
      itemsPerPage: itemsPerPage,
      totalPages: totalPages,
      localizedTitle: localizedTitle,
      onItemTap: _navigateToExploreItem,
      onItemMenu: _showTrackBottomSheet,
    );
  }

  Widget _buildExploreItem(ExploreItem item, ColorScheme colorScheme) {
    final cardSize = _exploreCardSize(context);
    final isAlbum = item.type == 'album';
    final isArtist = item.type == 'artist';
    final isPlaylist = item.type == 'playlist';

    if (isAlbum || isArtist || isPlaylist) {
      return Semantics(
        button: true,
        label: context.l10n.a11yOpenItem(item.type, item.name),
        child: Consumer(
          builder: (context, ref, _) {
            final lib = ref.watch(libraryCollectionsProvider);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                width: cardSize,
                height: cardSize + 48,
                child: _buildCardForType(
                  item,
                  cardSize,
                  isFavorite: isAlbum
                      ? lib.isFavoriteAlbum(
                          albumId: item.id,
                          providerId: item.providerId,
                          name: item.name,
                        )
                      : isArtist
                      ? lib.isFavoriteArtist(
                          artistId: item.id,
                          providerId: item.providerId,
                          name: item.name,
                        )
                      : lib.isFavoritePlaylist(
                          playlistId: item.id,
                          providerId: item.providerId,
                        ),
                  onHeartTap: () {
                    final notifier = ref.read(
                      libraryCollectionsProvider.notifier,
                    );
                    if (isAlbum) {
                      notifier.toggleFavoriteAlbum(
                        albumId: item.id,
                        providerId: item.providerId,
                        name: item.name,
                        imageUrl: item.coverUrl,
                      );
                    } else if (isArtist) {
                      notifier.toggleFavoriteArtist(
                        artistId: item.id,
                        providerId: item.providerId,
                        name: item.name,
                        imageUrl: item.coverUrl,
                      );
                    } else {
                      notifier.toggleFavoritePlaylist(
                        playlistId: item.id,
                        providerId: item.providerId,
                        name: item.name,
                        imageUrl: item.coverUrl,
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      );
    }

    return Semantics(
      button: true,
      label: context.l10n.a11yOpenItem(item.type, item.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
          width: cardSize,
          height: cardSize + 48,
          child: _buildCardForType(item, cardSize),
        ),
      ),
    );
  }

  Widget _buildCardForType(
    ExploreItem item,
    double cardSize, {
    bool isFavorite = false,
    VoidCallback? onHeartTap,
  }) {
    switch (item.type) {
      case 'album':
        return AlbumCard(
          albumName: item.name,
          artistName: item.artists,
          coverUrl: item.coverUrl,
          layout: AlbumCardLayout.grid,
          isFavorite: isFavorite,
          onHeartTap: onHeartTap,
          onTap: () => _navigateToExploreItem(item),
          width: cardSize,
          height: cardSize + 48,
        );
      case 'artist':
        return ArtistCard(
          artistName: item.name,
          imageUrl: item.coverUrl,
          layout: ArtistCardLayout.grid,
          isFavorite: isFavorite,
          onHeartTap: onHeartTap,
          onTap: () => _navigateToExploreItem(item),
        );
      case 'playlist':
        return PlaylistCard(
          playlistName: item.name,
          coverUrl: item.coverUrl,
          subtitle: item.artists.isNotEmpty ? item.artists : item.description,
          trackCount: 0,
          layout: PlaylistCardLayout.grid,
          isFavorite: isFavorite,
          onHeartTap: onHeartTap,
          onTap: () => _navigateToExploreItem(item),
          width: cardSize,
          height: cardSize + 48,
        );
      default:
        return _buildSimpleExploreCard(item, cardSize);
    }
  }

  Widget _buildSimpleExploreCard(ExploreItem item, double cardSize) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconSize = cardSize * 0.3;
    final cover = item.coverUrl != null && item.coverUrl!.isNotEmpty
        ? CachedCoverImage(
            imageUrl: item.coverUrl!,
            width: cardSize,
            height: cardSize,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Container(
              width: cardSize,
              height: cardSize,
              color: colorScheme.surfaceContainerHighest,
              child: Icon(
                _getIconForType(item.type),
                color: colorScheme.onSurfaceVariant,
                size: iconSize,
              ),
            ),
          )
        : null;

    return GestureDetector(
      onTap: () => _navigateToExploreItem(item),
      child: SizedBox(
        width: cardSize,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: cardSize,
            height: cardSize,
            child: Stack(
              children: [
                if (cover != null) Positioned.fill(child: cover),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                if (cover == null)
                  Center(
                    child: Icon(
                      _getIconForType(item.type),
                      color: colorScheme.onSurfaceVariant,
                      size: iconSize,
                    ),
                  ),
                if (cover != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: cardSize - 16,
                          height: cardSize - 16,
                          child: cover,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'track':
        return Icons.music_note;
      case 'album':
        return Icons.album;
      case 'playlist':
        return Icons.playlist_play;
      case 'artist':
        return Icons.person;
      case 'station':
        return Icons.radio;
      default:
        return Icons.music_note;
    }
  }

  String? _providerIdForExploreItem(ExploreItem item) {
    final itemProviderId = item.providerId?.trim();
    if (itemProviderId != null && itemProviderId.isNotEmpty) {
      return itemProviderId;
    }

    final feedProviderId = ref.read(exploreProvider).providerId?.trim();
    if (feedProviderId != null && feedProviderId.isNotEmpty) {
      return feedProviderId;
    }

    return null;
  }

  void _showMissingExploreProviderMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.extensionsNoHomeFeedExtensions)),
    );
  }

  void _navigateToExploreItem(ExploreItem item) async {
    final extensionId = _providerIdForExploreItem(item);

    switch (item.type) {
      case 'track':
        _showTrackBottomSheet(item);
        return;
      case 'album':
        if (extensionId == null) {
          _showMissingExploreProviderMessage();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => ExtensionAlbumScreen(
              extensionId: extensionId,
              albumId: item.id,
              albumName: item.name,
              coverUrl: item.coverUrl,
            ),
          ),
        );
        return;
      case 'playlist':
        if (extensionId == null) {
          _showMissingExploreProviderMessage();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => ExtensionPlaylistScreen(
              extensionId: extensionId,
              playlistId: item.id,
              playlistName: item.name,
              coverUrl: item.coverUrl,
            ),
          ),
        );
        return;
      case 'artist':
        if (extensionId == null) {
          _showMissingExploreProviderMessage();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => ExtensionArtistScreen(
              extensionId: extensionId,
              artistId: item.id,
              artistName: item.name,
              coverUrl: item.coverUrl,
            ),
          ),
        );
        return;
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${item.type}: ${item.name}')));
        return;
    }
  }

  void _showTrackBottomSheet(ExploreItem item) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                        ? CachedCoverImage(
                            imageUrl: item.coverUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.music_note,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        ClickableArtistName(
                          artistName: item.artists,
                          coverUrl: item.coverUrl,
                          extensionId: item.providerId,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.download, color: colorScheme.primary),
              title: Text(context.l10n.downloadTitle),
              onTap: () {
                Navigator.pop(context);
                _handleExploreTrackPrimaryAction(item);
              },
            ),
            ListTile(
              leading: Icon(Icons.album, color: colorScheme.onSurfaceVariant),
              title: Text(context.l10n.homeGoToAlbum),
              onTap: () {
                Navigator.pop(context);
                _navigateToTrackAlbum(item);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExploreTrackPrimaryAction(ExploreItem item) async {
    final settings = ref.read(settingsProvider);

    final track = Track(
      id: item.id,
      name: item.name,
      artistName: item.artists,
      albumName: item.albumName ?? '',
      albumId: item.albumId,
      duration: item.durationMs ~/ 1000,
      trackNumber: null,
      discNumber: null,
      totalDiscs: null,
      isrc: item.isrc,
      releaseDate: item.releaseDate,
      coverUrl: item.coverUrl,
      source: _providerIdForExploreItem(item),
    );

    if (settings.askQualityBeforeDownload) {
      DownloadServicePicker.show(
        context,
        trackName: track.name,
        artistName: track.artistName,
        coverUrl: track.coverUrl,
        onSelect: (quality, service) {
          ref
              .read(downloadQueueProvider.notifier)
              .addToQueue(track, service, qualityOverride: quality);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.snackbarAddedToQueue(track.name)),
            ),
          );
        },
      );
    } else {
      final extensionState = ref.read(extensionProvider);
      final service = resolveEffectiveDownloadService(
        settings.defaultService,
        extensionState,
      );
      if (service.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.extensionsNoDownloadProvider)),
        );
        return;
      }
      ref.read(downloadQueueProvider.notifier).addToQueue(track, service);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.snackbarAddedToQueue(track.name))),
      );
    }
  }

  Future<void> _navigateToTrackAlbum(ExploreItem item) async {
    if (item.albumId != null && item.albumId!.isNotEmpty) {
      final extensionId = _providerIdForExploreItem(item);
      if (extensionId == null) {
        _showMissingExploreProviderMessage();
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => ExtensionAlbumScreen(
            extensionId: extensionId,
            albumId: item.albumId!,
            albumName: item.albumName ?? 'Álbum',
            coverUrl: item.coverUrl,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.homeAlbumInfoUnavailable)),
      );
    }
  }

  Widget _buildRecentAccess(_RecentAccessView view, ColorScheme colorScheme) {
    final uniqueItems = view.uniqueItems;
    final downloadIds = view.downloadIds;
    final hasHiddenDownloads = view.hasHiddenDownloads;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
            Container(color: colorScheme.surface.withValues(alpha: 0.4)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.homeRecent,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (uniqueItems.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            for (final id in downloadIds) {
                              ref
                                  .read(recentAccessProvider.notifier)
                                  .hideDownloadFromRecents(id);
                            }
                            ref
                                .read(recentAccessProvider.notifier)
                                .clearHistory();
                          },
                          child: Text(
                            context.l10n.dialogClearAll,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (uniqueItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              hasHiddenDownloads
                                  ? Icons.visibility_off
                                  : Icons.history,
                              size: 48,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.recentEmpty,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            if (hasHiddenDownloads) ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  ref
                                      .read(recentAccessProvider.notifier)
                                      .clearHiddenDownloads();
                                },
                                icon: const Icon(Icons.visibility, size: 18),
                                label: Text(
                                  context.l10n.recentShowAllDownloads,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    ...uniqueItems.map(
                      (item) => _buildRecentAccessItem(
                        item,
                        colorScheme,
                        view.downloadFilePathByRecentKey,
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

  Widget _buildRecentAccessItem(
    RecentAccessItem item,
    ColorScheme colorScheme,
    Map<String, String> downloadFilePathByRecentKey,
  ) {
    final isDownloaded = item.providerId == 'download';

    switch (item.type) {
      case RecentAccessType.album:
        return AlbumCard(
          albumName: item.name,
          artistName: item.subtitle ?? '',
          coverUrl: item.imageUrl,
          layout: AlbumCardLayout.row,
          showDownloadedBadge: isDownloaded,
          trailing: _recentDismissButton(item, colorScheme),
          onTap: () => _navigateToRecentItem(item),
        );
      case RecentAccessType.track:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.surface.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: InkWell(
              onTap: () => _navigateToRecentItem(item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _DownloadedOrRemoteCover(
                      downloadedFilePath: isDownloaded
                          ? downloadFilePathByRecentKey['${item.type.name}:${item.id}']
                          : null,
                      imageUrl: item.imageUrl,
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.circular(4),
                      fallbackIcon: Icons.music_note,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isDownloaded
                                ? (item.subtitle != null
                                      ? '${context.l10n.recentTypeSong} • ${item.subtitle}'
                                      : context.l10n.recentTypeSong)
                                : (item.subtitle != null
                                      ? '${context.l10n.recentTypeSong} • ${item.subtitle}'
                                      : context.l10n.recentTypeSong),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDownloaded
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    _recentDismissButton(item, colorScheme),
                  ],
                ),
              ),
            ),
          ),
        );
      case RecentAccessType.artist:
      case RecentAccessType.playlist:
        final typeIcon = item.type == RecentAccessType.artist
            ? Icons.person
            : Icons.playlist_play;
        final typeLabel = item.type == RecentAccessType.artist
            ? context.l10n.recentTypeArtist
            : context.l10n.recentTypePlaylist;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.surface.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: InkWell(
              onTap: () => _navigateToRecentItem(item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _DownloadedOrRemoteCover(
                      downloadedFilePath: null,
                      imageUrl: item.imageUrl,
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.circular(
                        item.type == RecentAccessType.artist ? 28 : 4,
                      ),
                      fallbackIcon: typeIcon,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle != null
                                ? '$typeLabel • ${item.subtitle}'
                                : typeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    _recentDismissButton(item, colorScheme),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }

  Widget _recentDismissButton(RecentAccessItem item, ColorScheme colorScheme) {
    return IconButton(
      tooltip: context.l10n.actionDismiss,
      icon: Icon(Icons.close, size: 20, color: colorScheme.onSurfaceVariant),
      onPressed: () {
        if (item.providerId == 'download') {
          ref
              .read(recentAccessProvider.notifier)
              .hideDownloadFromRecents(item.id);
        } else {
          ref.read(recentAccessProvider.notifier).removeItem(item);
        }
      },
    );
  }

  bool _isEnabledMetadataExtension(String? providerId) {
    final normalized = providerId?.trim();
    if (normalized == null || normalized.isEmpty) return false;

    return ref
        .read(extensionProvider)
        .extensions
        .any(
          (ext) =>
              ext.enabled && ext.hasMetadataProvider && ext.id == normalized,
        );
  }

  Future<void> _navigateToRecentItem(RecentAccessItem item) async {
    _searchFocusNode.unfocus();

    switch (item.type) {
      case RecentAccessType.artist:
        if (_isEnabledMetadataExtension(item.providerId)) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => ExtensionArtistScreen(
                extensionId: item.providerId!,
                artistId: item.id,
                artistName: item.name,
                coverUrl: item.imageUrl,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => ArtistScreen(
                artistId: item.id,
                artistName: item.name,
                coverUrl: item.imageUrl,
              ),
            ),
          );
        }
        return;
      case RecentAccessType.album:
        if (item.providerId == 'download') {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => DownloadedAlbumScreen(
                albumName: item.name,
                artistName: item.subtitle ?? '',
                coverUrl: item.imageUrl,
              ),
            ),
          );
        } else if (_isEnabledMetadataExtension(item.providerId)) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => ExtensionAlbumScreen(
                extensionId: item.providerId!,
                albumId: item.id,
                albumName: item.name,
                coverUrl: item.imageUrl,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => AlbumScreen(
                albumId: item.id,
                albumName: item.name,
                coverUrl: item.imageUrl,
              ),
            ),
          );
        }
        return;
      case RecentAccessType.track:
        final historyItem = await ref
            .read(downloadHistoryProvider.notifier)
            .getBySpotifyIdAsync(item.id);
        if (!mounted) return;
        if (historyItem != null) {
          _navigateToMetadataScreen(historyItem);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(item.name)));
        }
        return;
      case RecentAccessType.playlist:
        if (item.id.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.recentPlaylistInfo(item.name))),
          );
          return;
        }

        if (_isEnabledMetadataExtension(item.providerId)) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => ExtensionPlaylistScreen(
                extensionId: item.providerId!,
                playlistId: item.id,
                playlistName: item.name,
                coverUrl: item.imageUrl,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => PlaylistScreen(
                playlistName: item.name,
                coverUrl: item.imageUrl,
                tracks: const [],
                playlistId: item.id,
              ),
            ),
          );
        }
        return;
    }
  }

  Future<void> _navigateToMetadataScreen(
    DownloadHistoryItem item, {
    List<DownloadHistoryItem>? navigationItems,
    int? navigationIndex,
  }) async {
    final navigator = Navigator.of(context);
    _precacheCover(item.coverUrl);
    final beforeModTime =
        await DownloadedEmbeddedCoverResolver.readFileModTimeMillis(
          item.filePath,
        );
    if (!mounted) return;
    final result = await navigator.push(
      slidePageRoute<bool>(
        page: TrackMetadataScreen(
          item: item,
          historyNavigationItems: navigationItems,
          navigationIndex: navigationIndex,
        ),
      ),
    );
    await DownloadedEmbeddedCoverResolver.scheduleRefreshForPath(
      item.filePath,
      beforeModTime: beforeModTime,
      force: result == true,
      onChanged: _onEmbeddedCoverChanged,
    );
  }

  void _precacheCover(String? url) {
    if (url == null || url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return;
    }
    final dpr = MediaQuery.devicePixelRatioOf(
      context,
    ).clamp(1.0, 3.0).toDouble();
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

  Widget _buildErrorWidget(String error, ColorScheme colorScheme) {
    final l10n = context.l10n;
    final isRateLimit =
        error.contains('429') ||
        error.toLowerCase().contains('rate limit') ||
        error.toLowerCase().contains('too many requests');
    final isUrlNotRecognized = error == 'url_not_recognized';

    if (isRateLimit) {
      return Card(
        elevation: 0,
        color: colorScheme.errorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.timer_off, color: colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.errorRateLimited,
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.errorRateLimitedMessage,
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontSize: 12,
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

    if (isUrlNotRecognized) {
      return Card(
        elevation: 0,
        color: colorScheme.errorContainer.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.link_off, color: colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.errorUrlNotRecognized,
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.errorUrlNotRecognizedMessage,
                      style: TextStyle(color: colorScheme.error, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: colorScheme.errorContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.errorUrlFetchFailed,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sortOptionLabel(_SearchSortOption option) {
    switch (option) {
      case _SearchSortOption.defaultOrder:
        return context.l10n.searchSortDefault;
      case _SearchSortOption.titleAsc:
        return context.l10n.searchSortTitleAZ;
      case _SearchSortOption.titleDesc:
        return context.l10n.searchSortTitleZA;
      case _SearchSortOption.artistAsc:
        return context.l10n.searchSortArtistAZ;
      case _SearchSortOption.artistDesc:
        return context.l10n.searchSortArtistZA;
      case _SearchSortOption.durationAsc:
        return context.l10n.searchSortDurationShort;
      case _SearchSortOption.durationDesc:
        return context.l10n.searchSortDurationLong;
      case _SearchSortOption.dateAsc:
        return context.l10n.searchSortDateOldest;
      case _SearchSortOption.dateDesc:
        return context.l10n.searchSortDateNewest;
    }
  }

  void _showSortOptions(ColorScheme colorScheme) {
    var tempSort = _searchSortOption;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        context.l10n.searchSortTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setSheetState(
                          () => tempSort = _SearchSortOption.defaultOrder,
                        ),
                        child: Text(context.l10n.libraryFilterReset),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _SearchSortOption.values.map((option) {
                      return FilterChip(
                        label: Text(_sortOptionLabel(option)),
                        selected: tempSort == option,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setSheetState(() => tempSort = option),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (_searchSortOption != tempSort) {
                          setState(() {
                            _searchSortOption = tempSort;
                          });
                        }
                      },
                      child: Text(context.l10n.libraryFilterApply),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<T> _applySortToList<T>(
    List<T> items,
    String Function(T) getName,
    String Function(T) getArtist,
    int Function(T) getDuration,
    String? Function(T) getDate,
  ) {
    if (_searchSortOption == _SearchSortOption.defaultOrder) return items;
    final sorted = List<T>.of(items);
    switch (_searchSortOption) {
      case _SearchSortOption.defaultOrder:
        break;
      case _SearchSortOption.titleAsc:
        sorted.sort(
          (a, b) =>
              getName(a).toLowerCase().compareTo(getName(b).toLowerCase()),
        );
      case _SearchSortOption.titleDesc:
        sorted.sort(
          (a, b) =>
              getName(b).toLowerCase().compareTo(getName(a).toLowerCase()),
        );
      case _SearchSortOption.artistAsc:
        sorted.sort(
          (a, b) =>
              getArtist(a).toLowerCase().compareTo(getArtist(b).toLowerCase()),
        );
      case _SearchSortOption.artistDesc:
        sorted.sort(
          (a, b) =>
              getArtist(b).toLowerCase().compareTo(getArtist(a).toLowerCase()),
        );
      case _SearchSortOption.durationAsc:
        sorted.sort((a, b) => getDuration(a).compareTo(getDuration(b)));
      case _SearchSortOption.durationDesc:
        sorted.sort((a, b) => getDuration(b).compareTo(getDuration(a)));
      case _SearchSortOption.dateAsc:
        sorted.sort((a, b) {
          final da = getDate(a) ?? '';
          final db = getDate(b) ?? '';
          return da.compareTo(db);
        });
      case _SearchSortOption.dateDesc:
        sorted.sort((a, b) {
          final da = getDate(a) ?? '';
          final db = getDate(b) ?? '';
          return db.compareTo(da);
        });
    }
    return sorted;
  }

  List<SearchArtist>? _sortSearchArtists(List<SearchArtist>? artists) {
    if (artists == null ||
        artists.isEmpty ||
        _searchSortOption == _SearchSortOption.defaultOrder) {
      return artists;
    }
    if (identical(artists, _sortedArtistsSource) &&
        _sortedArtistsMode == _searchSortOption &&
        _sortedArtistsCache != null) {
      return _sortedArtistsCache;
    }
    final sorted = _applySortToList<SearchArtist>(
      artists,
      (a) => a.name,
      (a) => a.name,
      (a) => 0,
      (a) => null,
    );
    _sortedArtistsSource = artists;
    _sortedArtistsMode = _searchSortOption;
    _sortedArtistsCache = sorted;
    return sorted;
  }

  List<SearchAlbum>? _sortSearchAlbums(List<SearchAlbum>? albums) {
    if (albums == null ||
        albums.isEmpty ||
        _searchSortOption == _SearchSortOption.defaultOrder) {
      return albums;
    }
    if (identical(albums, _sortedAlbumsSource) &&
        _sortedAlbumsMode == _searchSortOption &&
        _sortedAlbumsCache != null) {
      return _sortedAlbumsCache;
    }
    final sorted = _applySortToList<SearchAlbum>(
      albums,
      (a) => a.name,
      (a) => a.artists,
      (a) => 0,
      (a) => a.releaseDate,
    );
    _sortedAlbumsSource = albums;
    _sortedAlbumsMode = _searchSortOption;
    _sortedAlbumsCache = sorted;
    return sorted;
  }

  List<SearchPlaylist>? _sortSearchPlaylists(List<SearchPlaylist>? playlists) {
    if (playlists == null ||
        playlists.isEmpty ||
        _searchSortOption == _SearchSortOption.defaultOrder) {
      return playlists;
    }
    if (identical(playlists, _sortedPlaylistsSource) &&
        _sortedPlaylistsMode == _searchSortOption &&
        _sortedPlaylistsCache != null) {
      return _sortedPlaylistsCache;
    }
    final sorted = _applySortToList<SearchPlaylist>(
      playlists,
      (p) => p.name,
      (p) => p.owner,
      (p) => 0,
      (p) => null,
    );
    _sortedPlaylistsSource = playlists;
    _sortedPlaylistsMode = _searchSortOption;
    _sortedPlaylistsCache = sorted;
    return sorted;
  }

  ({List<Track> tracks, List<int> indexes}) _sortTrackResults(
    List<Track> tracks,
    List<int> indexes,
  ) {
    if (tracks.isEmpty || _searchSortOption == _SearchSortOption.defaultOrder) {
      return (tracks: tracks, indexes: indexes);
    }
    if (identical(tracks, _sortedTracksSource) &&
        identical(indexes, _sortedTrackIndexesSource) &&
        _sortedTracksMode == _searchSortOption &&
        _sortedTracksCache != null &&
        _sortedTrackIndexesCache != null) {
      return (tracks: _sortedTracksCache!, indexes: _sortedTrackIndexesCache!);
    }
    final paired = List.generate(
      tracks.length,
      (i) => (tracks[i], indexes[i]),
      growable: false,
    );
    final sortedPairs = _applySortToList<(Track, int)>(
      paired,
      (p) => p.$1.name,
      (p) => p.$1.artistName,
      (p) => p.$1.duration,
      (p) => p.$1.releaseDate,
    );
    final sortedTracks = sortedPairs.map((p) => p.$1).toList(growable: false);
    final sortedIndexes = sortedPairs.map((p) => p.$2).toList(growable: false);
    _sortedTracksSource = tracks;
    _sortedTrackIndexesSource = indexes;
    _sortedTracksMode = _searchSortOption;
    _sortedTracksCache = sortedTracks;
    _sortedTrackIndexesCache = sortedIndexes;
    return (tracks: sortedTracks, indexes: sortedIndexes);
  }

  List<Widget> _buildSearchResults({
    required List<Track> tracks,
    required List<SearchArtist>? searchArtists,
    required List<SearchAlbum>? searchAlbums,
    required List<SearchPlaylist>? searchPlaylists,
    required bool isLoading,
    required String? error,
    required ColorScheme colorScheme,
    required bool hasResults,
    required String? searchExtensionId,
    required bool showLocalLibraryIndicator,
    required Map<String, (double, double)> thumbnailSizesByExtensionId,
  }) {
    final hasActualData =
        tracks.isNotEmpty ||
        (searchArtists != null && searchArtists.isNotEmpty) ||
        (searchAlbums != null && searchAlbums.isNotEmpty) ||
        (searchPlaylists != null && searchPlaylists.isNotEmpty);

    if (!hasActualData && isLoading) {
      return [const SliverToBoxAdapter(child: HomeSearchSkeleton())];
    }
    if (!hasResults) {
      return [const SliverToBoxAdapter(child: SizedBox.shrink())];
    }

    final buckets = _getSearchResultBuckets(tracks);
    final realTracks = buckets.realTracks;
    final realTrackIndexes = buckets.realTrackIndexes;
    final albumItems = buckets.albumItems;
    final playlistItems = buckets.playlistItems;
    final artistItems = buckets.artistItems;

    final sortedArtists = _sortSearchArtists(searchArtists);
    final sortedAlbums = _sortSearchAlbums(searchAlbums);
    final sortedPlaylists = _sortSearchPlaylists(searchPlaylists);
    final sortedTrackResults = _sortTrackResults(realTracks, realTrackIndexes);
    final sortedTracks = sortedTrackResults.tracks;
    final sortedTrackIndexes = sortedTrackResults.indexes;

    final slivers = <Widget>[
      if (error != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildErrorWidget(error, colorScheme),
          ),
        ),
      if (isLoading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(),
          ),
        ),
    ];

    bool sortButtonShown = false;

    if (sortedArtists != null && sortedArtists.isNotEmpty) {
      slivers.addAll(
        _buildGridResultSection(
          title: context.l10n.searchArtists,
          itemCount: sortedArtists.length,
          colorScheme: colorScheme,
          showSortButton: !sortButtonShown,
          itemBuilder: (index) {
            final a = sortedArtists[index];
            return Consumer(
              builder: (context, ref, _) {
                final isFav = ref.watch(
                  libraryCollectionsProvider.select(
                    (s) => s.isFavoriteArtist(
                      artistId: a.id,
                      providerId: null,
                      name: a.name,
                    ),
                  ),
                );
                return ArtistCard(
                  key: ValueKey('search-artist-${a.id}'),
                  artistName: a.name,
                  imageUrl: a.imageUrl,
                  isFavorite: isFav,
                  onHeartTap: () => ref
                      .read(libraryCollectionsProvider.notifier)
                      .toggleFavoriteArtist(
                        artistId: a.id,
                        providerId: null,
                        name: a.name,
                        imageUrl: a.imageUrl,
                      ),
                  onTap: () => _navigateToArtist(
                    a.id,
                    a.name,
                    a.imageUrl,
                    providerId: searchExtensionId ?? 'deezer',
                  ),
                );
              },
            );
          },
        ),
      );
      sortButtonShown = true;
    }

    if (artistItems.isNotEmpty) {
      slivers.addAll(
        _buildGridResultSection(
          title: context.l10n.searchArtists,
          itemCount: artistItems.length,
          colorScheme: colorScheme,
          showSortButton: !sortButtonShown,
          itemBuilder: (index) {
            final a = artistItems[index];
            return Consumer(
              builder: (context, ref, _) {
                final isFav = ref.watch(
                  libraryCollectionsProvider.select(
                    (s) => s.isFavoriteArtist(
                      artistId: a.id,
                      providerId: null,
                      name: a.name,
                    ),
                  ),
                );
                return ArtistCard(
                  key: ValueKey('artist-${a.id}'),
                  artistName: a.name,
                  imageUrl: a.coverUrl,
                  isFavorite: isFav,
                  onHeartTap: () => ref
                      .read(libraryCollectionsProvider.notifier)
                      .toggleFavoriteArtist(
                        artistId: a.id,
                        providerId: null,
                        name: a.name,
                        imageUrl: a.coverUrl,
                      ),
                  onTap: () => _navigateToExtensionArtist(a),
                );
              },
            );
          },
        ),
      );
      sortButtonShown = true;
    }

    if (sortedAlbums != null && sortedAlbums.isNotEmpty) {
      slivers.addAll(
        _buildGridResultSection(
          title: context.l10n.searchAlbums,
          itemCount: sortedAlbums.length,
          colorScheme: colorScheme,
          showSortButton: !sortButtonShown,
          itemBuilder: (index) {
            final sa = sortedAlbums[index];
            final albumName = sa.name;
            return Consumer(
              builder: (context, ref, _) {
                final historyState = ref.watch(downloadHistoryProvider);
                final favAlbums = ref.watch(
                  libraryCollectionsProvider.select((s) => s.favoriteAlbums),
                );
                final isDownloaded = historyState.items.any(
                  (h) => h.albumName.toLowerCase() == albumName.toLowerCase(),
                );
                final n = normalizeForMatch(sa.name);
                final isFav = favAlbums.any(
                  (e) => normalizeForMatch(e.name) == n,
                );
                return AlbumCard(
                  key: ValueKey('search-album-${sa.id}'),
                  albumName: sa.name,
                  artistName: sa.artists,
                  coverUrl: sa.imageUrl,
                  layout: AlbumCardLayout.grid,
                  showDownloadedBadge: isDownloaded,
                  isFavorite: isFav,
                  onHeartTap: () => ref
                      .read(libraryCollectionsProvider.notifier)
                      .toggleFavoriteAlbum(
                        albumId: sa.id,
                        providerId: null,
                        name: sa.name,
                        artistName: sa.artists,
                        imageUrl: sa.imageUrl,
                      ),
                  onTap: () => _navigateToSearchAlbum(
                    sa,
                    providerId: searchExtensionId ?? 'deezer',
                  ),
                );
              },
            );
          },
        ),
      );
      sortButtonShown = true;
    }

    if (albumItems.isNotEmpty) {
      slivers.addAll(
        _buildGridResultSection(
          title: context.l10n.searchAlbums,
          itemCount: albumItems.length,
          colorScheme: colorScheme,
          showSortButton: !sortButtonShown,
          itemBuilder: (index) {
            final albumTrack = albumItems[index];
            final albumName = albumTrack.name;
            return Consumer(
              builder: (context, ref, _) {
                final historyState = ref.watch(downloadHistoryProvider);
                final favAlbums = ref.watch(
                  libraryCollectionsProvider.select((s) => s.favoriteAlbums),
                );
                final isDownloaded = historyState.items.any(
                  (h) => h.albumName.toLowerCase() == albumName.toLowerCase(),
                );
                final n = normalizeForMatch(albumTrack.name);
                final isFav = favAlbums.any(
                  (e) => normalizeForMatch(e.name) == n,
                );
                return AlbumCard(
                  key: ValueKey('album-${albumTrack.id}'),
                  albumName: albumTrack.name,
                  artistName: albumTrack.artistName,
                  coverUrl: albumTrack.coverUrl,
                  layout: AlbumCardLayout.grid,
                  showDownloadedBadge: isDownloaded,
                  isFavorite: isFav,
                  onHeartTap: () => ref
                      .read(libraryCollectionsProvider.notifier)
                      .toggleFavoriteAlbum(
                        albumId: albumTrack.albumId ?? albumTrack.id,
                        providerId: searchExtensionId,
                        name: albumTrack.name,
                        artistName: albumTrack.artistName,
                        imageUrl: albumTrack.coverUrl,
                      ),
                  onTap: () => _navigateToExtensionAlbum(albumTrack),
                );
              },
            );
          },
        ),
      );
      sortButtonShown = true;
    }

    if (sortedPlaylists != null && sortedPlaylists.isNotEmpty) {
      slivers.addAll(
        _buildGridResultSection(
          title: context.l10n.searchPlaylists,
          itemCount: sortedPlaylists.length,
          colorScheme: colorScheme,
          showSortButton: !sortButtonShown,
          itemBuilder: (index) {
            final p = sortedPlaylists[index];
            return Consumer(
              builder: (context, ref, _) {
                final favPlaylists = ref.watch(
                  libraryCollectionsProvider.select((s) => s.favoritePlaylists),
                );
                final n = normalizeForMatch(p.name);
                final isFav = favPlaylists.any(
                  (e) => normalizeForMatch(e.name) == n,
                );
                return PlaylistCard(
                  key: ValueKey('search-playlist-${p.id}'),
                  playlistName: p.name,
                  coverUrl: p.imageUrl,
                  subtitle: p.owner.isNotEmpty ? p.owner : null,
                  isFavorite: isFav,
                  onHeartTap: () => ref
                      .read(libraryCollectionsProvider.notifier)
                      .toggleFavoritePlaylist(
                        playlistId: p.id,
                        providerId: searchExtensionId ?? 'deezer',
                        name: p.name,
                        imageUrl: p.imageUrl,
                      ),
                  onTap: () => _navigateToSearchPlaylist(
                    p,
                    providerId: searchExtensionId ?? 'deezer',
                  ),
                );
              },
            );
          },
        ),
      );
      sortButtonShown = true;
    }

    if (playlistItems.isNotEmpty) {
      slivers.addAll(
        _buildGridResultSection(
          title: context.l10n.searchPlaylists,
          itemCount: playlistItems.length,
          colorScheme: colorScheme,
          showSortButton: !sortButtonShown,
          itemBuilder: (index) {
            final p = playlistItems[index];
            return Consumer(
              builder: (context, ref, _) {
                final favPlaylists = ref.watch(
                  libraryCollectionsProvider.select((s) => s.favoritePlaylists),
                );
                final n = normalizeForMatch(p.name);
                final isFav = favPlaylists.any(
                  (e) => normalizeForMatch(e.name) == n,
                );
                return PlaylistCard(
                  key: ValueKey('playlist-${p.id}'),
                  playlistName: p.name,
                  coverUrl: p.coverUrl,
                  subtitle: p.artistName.isNotEmpty ? p.artistName : null,
                  isFavorite: isFav,
                  onHeartTap: () => ref
                      .read(libraryCollectionsProvider.notifier)
                      .toggleFavoritePlaylist(
                        playlistId: p.id,
                        providerId: searchExtensionId,
                        name: p.name,
                        imageUrl: p.coverUrl,
                      ),
                  onTap: () => _navigateToExtensionPlaylist(p),
                );
              },
            );
          },
        ),
      );
      sortButtonShown = true;
    }

    if (sortedTracks.isNotEmpty) {
      slivers.addAll(
        _buildVirtualizedResultSection(
          title: context.l10n.searchSongs,
          itemCount: sortedTracks.length,
          colorScheme: colorScheme,
          showSortButton: !sortButtonShown,
          itemBuilder: (index, showDivider) => _TrackItemWithStatus(
            key: ValueKey(sortedTracks[index].id),
            track: sortedTracks[index],
            index: sortedTrackIndexes[index],
            onDownload: () => _downloadTrack(sortedTrackIndexes[index]),
            searchExtensionId: searchExtensionId,
            showLocalLibraryIndicator: showLocalLibraryIndicator,
            thumbnailSizesByExtensionId: thumbnailSizesByExtensionId,
          ),
        ),
      );
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
    return slivers;
  }

  List<Widget> _buildVirtualizedResultSection({
    required String title,
    required int itemCount,
    required ColorScheme colorScheme,
    required Widget Function(int index, bool showDivider) itemBuilder,
    bool showSortButton = false,
  }) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (showSortButton)
                SizedBox(
                  height: 32,
                  child: TextButton.icon(
                    onPressed: () => _showSortOptions(colorScheme),
                    icon: Icon(
                      Icons.swap_vert,
                      size: 18,
                      color: _searchSortOption != _SearchSortOption.defaultOrder
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      _searchSortOption != _SearchSortOption.defaultOrder
                          ? _sortOptionLabel(_searchSortOption)
                          : context.l10n.libraryFilterSort,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            _searchSortOption != _SearchSortOption.defaultOrder
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final isFirst = index == 0;
          final isLast = index == itemCount - 1;
          return StaggeredListItem(
            index: index,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.vertical(
                  top: isFirst ? const Radius.circular(20) : Radius.zero,
                  bottom: isLast ? const Radius.circular(20) : Radius.zero,
                ),
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : BorderSide(
                          color: Colors.white.withValues(alpha: 0.06),
                          width: 0.5,
                        ),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: itemBuilder(index, !isLast),
              ),
            ),
          );
        }, childCount: itemCount),
      ),
    ];
  }

  List<Widget> _buildGridResultSection({
    required String title,
    required int itemCount,
    required ColorScheme colorScheme,
    required Widget Function(int index) itemBuilder,
    bool showSortButton = false,
  }) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (showSortButton)
                SizedBox(
                  height: 32,
                  child: TextButton.icon(
                    onPressed: () => _showSortOptions(colorScheme),
                    icon: Icon(
                      Icons.swap_vert,
                      size: 18,
                      color: _searchSortOption != _SearchSortOption.defaultOrder
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      _searchSortOption != _SearchSortOption.defaultOrder
                          ? _sortOptionLabel(_searchSortOption)
                          : context.l10n.libraryFilterSort,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            _searchSortOption != _SearchSortOption.defaultOrder
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 128,
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => itemBuilder(index),
            childCount: itemCount,
          ),
        ),
      ),
    ];
  }

  void _navigateToArtist(
    String artistId,
    String artistName,
    String? imageUrl, {
    String? providerId,
  }) {
    ref.read(settingsProvider.notifier).setHasSearchedBefore();

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ArtistScreen(
          artistId: artistId,
          artistName: artistName,
          coverUrl: imageUrl,
          extensionId: providerId,
        ),
      ),
    );
  }

  void _navigateToSearchAlbum(SearchAlbum album, {String? providerId}) {
    final src = providerId ?? 'deezer';
    ref.read(settingsProvider.notifier).setHasSearchedBefore();

    ref
        .read(recentAccessProvider.notifier)
        .recordAlbumAccess(
          id: album.id,
          name: album.name,
          artistName: album.artists,
          imageUrl: album.imageUrl,
          providerId: src,
        );

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => AlbumScreen(
          albumId: album.id,
          albumName: album.name,
          coverUrl: album.imageUrl,
          tracks: const [],
          extensionId: src,
        ),
      ),
    );
  }

  void _navigateToSearchPlaylist(
    SearchPlaylist playlist, {
    String? providerId,
  }) {
    final src = providerId ?? 'deezer';
    ref.read(settingsProvider.notifier).setHasSearchedBefore();

    ref
        .read(recentAccessProvider.notifier)
        .recordPlaylistAccess(
          id: playlist.id,
          name: playlist.name,
          ownerName: playlist.owner,
          imageUrl: playlist.imageUrl,
          providerId: src,
        );

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => PlaylistScreen(
          playlistName: playlist.name,
          coverUrl: playlist.imageUrl,
          tracks: const [],
          playlistId: playlist.id,
          extensionId: src,
        ),
      ),
    );
  }

  void _navigateToExtensionAlbum(Track albumItem) async {
    final extensionId = albumItem.source;
    if (extensionId == null || extensionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorMissingExtensionSource('album')),
        ),
      );
      return;
    }

    ref.read(settingsProvider.notifier).setHasSearchedBefore();

    ref
        .read(recentAccessProvider.notifier)
        .recordAlbumAccess(
          id: albumItem.id,
          name: albumItem.name,
          artistName: albumItem.artistName,
          imageUrl: albumItem.coverUrl,
          providerId: extensionId,
        );

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ExtensionAlbumScreen(
          extensionId: extensionId,
          albumId: albumItem.id,
          albumName: albumItem.name,
          coverUrl: albumItem.coverUrl,
          initialAlbumType: albumItem.albumType,
          initialTotalTracks: albumItem.totalTracks,
        ),
      ),
    );
  }

  void _navigateToExtensionPlaylist(Track playlistItem) async {
    final extensionId = playlistItem.source;
    if (extensionId == null || extensionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorMissingExtensionSource('playlist')),
        ),
      );
      return;
    }

    ref.read(settingsProvider.notifier).setHasSearchedBefore();

    ref
        .read(recentAccessProvider.notifier)
        .recordPlaylistAccess(
          id: playlistItem.id,
          name: playlistItem.name,
          ownerName: playlistItem.artistName,
          imageUrl: playlistItem.coverUrl,
          providerId: extensionId,
        );

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ExtensionPlaylistScreen(
          extensionId: extensionId,
          playlistId: playlistItem.id,
          playlistName: playlistItem.name,
          coverUrl: playlistItem.coverUrl,
        ),
      ),
    );
  }

  void _navigateToExtensionArtist(Track artistItem) {
    final extensionId = artistItem.source;
    if (extensionId == null || extensionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorMissingExtensionSource('artist')),
        ),
      );
      return;
    }

    ref.read(settingsProvider.notifier).setHasSearchedBefore();

    ref
        .read(recentAccessProvider.notifier)
        .recordArtistAccess(
          id: artistItem.id,
          name: artistItem.name,
          imageUrl: artistItem.coverUrl,
          providerId: extensionId,
        );

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ExtensionArtistScreen(
          extensionId: extensionId,
          artistId: artistItem.id,
          artistName: artistItem.name,
          coverUrl: artistItem.coverUrl,
        ),
      ),
    );
  }

  String _getSearchHint() {
    final settings = ref.read(settingsProvider);
    final extState = ref.read(extensionProvider);
    final searchProvider = _resolveSearchProvider(
      settings.searchProvider,
      extState.extensions,
    );

    if (!extState.isInitialized) {
      return context.l10n.homeSearchHintDefault;
    }

    if (searchProvider != null && searchProvider.isNotEmpty) {
      final ext = extState.extensions
          .where((e) => e.id == searchProvider)
          .firstOrNull;
      if (ext != null && ext.enabled) {
        if (ext.searchBehavior?.placeholder != null) {
          return ext.searchBehavior!.placeholder!;
        }
        return context.l10n.homeSearchHintProvider(ext.displayName);
      }
    }
    return context.l10n.homeSearchHintDefault;
  }

  Widget _buildSearchFilterBar(
    List<SearchFilter> filters,
    String? selectedFilter,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _GlassFilterChip(
                label: context.l10n.historyFilterAll,
                selected: selectedFilter == 'all',
                colorScheme: colorScheme,
                onTap: () {
                  print('[DEBUG] Filter "all" chip tapped');
                  ref.read(trackProvider.notifier).setSearchFilter('all');
                  _triggerSearchWithFilter('all');
                },
              ),
            ),
            ...filters.map((filter) {
              final isSelected = selectedFilter == filter.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _GlassFilterChip(
                  label: filter.label ?? filter.id,
                  selected: isSelected,
                  colorScheme: colorScheme,
                  icon: filter.icon != null
                      ? _getFilterIcon(filter.icon!)
                      : null,
                  onTap: () {
                    print(
                      '[DEBUG] Filter "${filter.id}" chip tapped (label: ${filter.label})',
                    );
                    ref.read(trackProvider.notifier).setSearchFilter(filter.id);
                    _triggerSearchWithFilter(filter.id);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _getFilterIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'music':
      case 'track':
      case 'song':
        return Icons.music_note;
      case 'album':
        return Icons.album;
      case 'artist':
        return Icons.person;
      case 'playlist':
        return Icons.playlist_play;
      case 'video':
        return Icons.video_library;
      case 'podcast':
        return Icons.podcasts;
      default:
        return Icons.search;
    }
  }

  void _triggerSearchWithFilter(String? filter) {
    final text = _urlController.text.trim();
    // Si ya hay resultados de búsqueda, permitir cambiar el filtro incluso con texto corto
    final trackState = ref.read(trackProvider);
    final hasExistingResults =
        trackState.hasContent || trackState.hasSearchText;

    print(
      '[DEBUG] _triggerSearchWithFilter called with filter=$filter, text="$text", hasExistingResults=$hasExistingResults',
    );

    if (text.isEmpty) {
      print('[DEBUG] Aborting: text is empty');
      return;
    }
    if (!hasExistingResults && text.length < _minLiveSearchChars) {
      print(
        '[DEBUG] Aborting: no existing results and text too short (${text.length} < $_minLiveSearchChars)',
      );
      return;
    }
    if (text.startsWith('http') || text.startsWith('spotify:')) {
      print('[DEBUG] Aborting: text is URL or Spotify URI');
      return;
    }

    print('[DEBUG] Proceeding with search: filter=$filter');
    _lastSearchQuery = null;
    _performSearch(text, filterOverride: filter);
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    final hasText = _urlController.text.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.transparent),
          ),
          Container(color: colorScheme.surface.withValues(alpha: 0.55)),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 0.5,
                ),
              ),
            ),
          ),
          TextField(
            controller: _urlController,
            focusNode: _searchFocusNode,
            autofocus: false,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: _getSearchHint(),
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              prefixIcon: _SearchProviderDropdown(
                onProviderChanged: () {
                  _lastSearchQuery = null;
                  ref.read(trackProvider.notifier).setSearchFilter(null);
                  setState(() {});
                  final text = _urlController.text.trim();
                  if (text.isNotEmpty && text.length >= _minLiveSearchChars) {
                    _performSearch(text);
                  }
                },
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasText)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: _clearAndRefresh,
                        tooltip: context.l10n.dialogClear,
                      ),
                    )
                  else ...[
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        icon: Icon(
                          Icons.file_upload_outlined,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: _isCsvImporting
                            ? null
                            : () => _importCsv(context, ref),
                        tooltip: context.l10n.homeImportCsvTooltip,
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        icon: Icon(
                          Icons.paste,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: _pasteFromClipboard,
                        tooltip: context.l10n.actionPaste,
                      ),
                    ),
                  ],
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            onSubmitted: (_) => _onSearchSubmitted(),
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
            },
          ),
        ],
      ),
    );
  }

  void _onSearchSubmitted() {
    _liveSearchDebounce?.cancel();
    _pendingLiveSearchQuery = null;

    final text = _urlController.text.trim();
    if (text.isEmpty) return;

    if (text.startsWith('http') || text.startsWith('spotify:')) {
      _fetchMetadata();
      _searchFocusNode.unfocus();
      return;
    }

    if (text.length >= 2) {
      _performSearch(text);
    }
    _searchFocusNode.unfocus();
  }
}

class _UsernamePrompt extends ConsumerWidget {
  final ColorScheme colorScheme;
  const _UsernamePrompt({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(settingsProvider.select((s) => s.username));
    if (username.isEmpty) {
      return TextButton.icon(
        onPressed: () => _showUsernameDialog(context, ref, username),
        icon: Icon(Icons.person_add_alt_1, size: 18),
        label: Text('Ingresar nombre'),
      );
    }
    return Row(
      children: [
        Icon(Icons.waving_hand, size: 20, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          'Hola $username',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _showUsernameDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ingresá tu nombre...'),
          onSubmitted: (value) {
            ref.read(settingsProvider.notifier).setUsername(value.trim());
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(settingsProvider.notifier)
                  .setUsername(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
