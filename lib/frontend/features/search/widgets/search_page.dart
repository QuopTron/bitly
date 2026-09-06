import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/feed_models.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/utils/item_actions.dart';
import '../../../shared/constants/source_constants.dart';
import '../../../../backend/services/like_cubit.dart';
import '../../../../backend/services/download_cubit.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/source_accordion.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';
import '../../../shared/theme/app_colors.dart';
import 'search_bar_widget.dart';
import 'search_results.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;  /// The active search source. Always non-empty — every search targets a
  /// single extension (no "Todas" mode). Defaults to the first available
  /// source; persisted across sessions so the user doesn't re-select every time.
  String _selectedSource = '';
  /// Default category: 'tracks' (canciones). There is NO "all" state — the four
  /// category bubbles (tracks/albums/artists/playlists) always have exactly one
  /// active, matching SpotiFLAC minus the "all" bubble. Always non-null.
  String? _selectedType = 'tracks';


  bool _searching = false;

  static const _prefKey = 'search_source';

  @override
  void initState() {
    super.initState();
    _loadPersistedSource();
  }

  Future<void> _loadPersistedSource() async {
    final bloc = context.read<SearchBloc>();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      // If saved source is empty (legacy "Todas"), fall through to first extension
      if (saved.isNotEmpty) {
        setState(() => _selectedSource = saved);
      } else {
        final sources = _searchSources(bloc.state);
        if (sources.isNotEmpty) {
          if (mounted) setState(() => _selectedSource = sources.keys.first);
        }
      }
    } else {
      // First time: default to the first available source
      final sources = _searchSources(bloc.state);
      if (sources.isNotEmpty) {
        final first = sources.keys.first;
        if (mounted) {
          setState(() => _selectedSource = first);
        }
      }
    }
    if (mounted) {
      bloc.add(SearchSourceChanged(_selectedSource));
    }
  }

  Future<void> _savePersistedSource(String src) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, src);
  }

  /// The manifest-declared category bubbles for the current source, or a
  /// sensible default when the config hasn't loaded yet.
  List<SearchFilterConfig> _filtersFor(SearchState state, String source) {
    final cfg = state.searchConfig[source];
    if (cfg != null && cfg.filters.isNotEmpty) return cfg.filters;
    return const [
      SearchFilterConfig(id: 'tracks', label: ''),
      SearchFilterConfig(id: 'artists', label: ''),
      SearchFilterConfig(id: 'albums', label: ''),
      SearchFilterConfig(id: 'playlists', label: ''),
    ];
  }

  /// Searchable sources for the selector, from the authoritative backend config
  /// (every bundled extension that declares a searchBehavior). The manifest
  /// primary source (deezer — SpotiFLAC's defaultSearchExtension) is listed
  /// first, then the rest. Falls back to a curated list while loading.
  Map<String, String> _searchSources(SearchState state) {
    // Per-extension search only — each source searches independently
    // for faster, more focused results. No "Todas" mode.
    final ordered = <String, String>{};
    final cfg = state.searchConfig;
    if (cfg.isNotEmpty) {
      final primary = cfg.entries.where((e) => e.value.primary).toList();
      final rest = cfg.entries.where((e) => !e.value.primary).toList();
      for (final e in [...primary, ...rest]) {
        ordered[e.key] = sourceDisplayName(e.key);
      }
      return ordered;
    }
    for (final s in const [
      'deezer', 'spotify-web', 'apple-music', 'soundcloud', 'amazon',
      'qobuz-web', 'tidal-web', 'ytmusic-spotiflac',
    ]) {
      ordered[s] = sourceDisplayName(s);
    }
    return ordered;
  }

  /// Placeholder hint for the search bar: the active source's manifest
  /// placeholder when one is selected, the primary source's placeholder for
  /// the "Todas" default (SpotiFLAC shows the primary source's hint), or null
  /// to fall back to the generic localized hint.
  String? _searchHint(SearchState state) {
    final cfg = state.searchConfig;
    if (cfg.isEmpty) return null;
    if (_selectedSource.isNotEmpty && cfg[_selectedSource] != null) {
      final p = cfg[_selectedSource]!.placeholder;
      if (p.isNotEmpty) return p;
      return null;
    }
    final primary = cfg.values.where((c) => c.primary).toList();
    if (primary.isNotEmpty && primary.first.placeholder.isNotEmpty) {
      return primary.first.placeholder;
    }
    return null;
  }

  bool _sourceHasCategory(SearchState state, String source, String cat) {
    return _filtersFor(state, source).any((f) => searchCategoryOf(f.id) == cat);
  }

  /// The manifest filter id for the active category (e.g. amazon "songs" vs
  /// apple "tracks"), or null when no category is selected.
  String? get _activeFilterId {
    if (_selectedType == null) return null;
    final state = context.read<SearchBloc>().state;
    for (final f in _filtersFor(state, _selectedSource)) {
      if (searchCategoryOf(f.id) == _selectedType) return f.id;
    }
    return _selectedType;
  }

  /// SpotiFLAC limits: 50 for tracks, 20 for the rest when re-querying a
  /// category. The "all" mix uses a lighter 25 (extension caps albums/artists).
  int _limitForType(String cat) => cat == 'tracks' ? 50 : 20;

  /// When "Todas" is active, we always search with source="" (all providers
  /// in parallel) and request a high limit so every category has results.
  /// The type chips then filter CLIENT-SIDE from the cached results — no
  /// re-query, just like SpotiFLAC.
  void _performSearch() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    // Always search a single extension — faster and more focused.
    final filterId = _activeFilterId;
    final type = filterId ?? 'tracks';
    final limit = filterId == null ? 25 : _limitForType(_selectedType!);
    context.read<SearchBloc>().add(
      PerformSearch(query: q, source: _selectedSource, type: type, limit: limit),
    );
  }

  void _onSourceChanged(String src) {
    setState(() {
      _selectedSource = src;
      // Keep a valid category selected (never drop to "all"). If the new
      // source doesn't declare the current one, fall back to 'tracks'.
      final state = context.read<SearchBloc>().state;
      if (_selectedType == null || !_sourceHasCategory(state, src, _selectedType!)) {
        _selectedType = 'tracks';
      }
    });
    _savePersistedSource(src);
    context.read<SearchBloc>().add(SearchSourceChanged(src));
    _performSearch();
  }

  void _onTypeChanged(String? t) {
    setState(() => _selectedType = t);
    // Always re-query the backend for the new category.
    _performSearch();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searching = false);
      context.read<SearchBloc>().add(const ClearSearch());
      return;
    }
    setState(() => _searching = true);
    final q = value.trim();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final filterId = _activeFilterId;
      final type = filterId ?? 'tracks';
      final limit = filterId == null ? 25 : _limitForType(_selectedType!);
      context.read<SearchBloc>().add(
        PerformSearch(query: q, source: _selectedSource, type: type, limit: limit),
      );
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchCtrl.clear();
    context.read<SearchBloc>().add(const ClearSearch());
  }

  void _toggleLike(String id, [FeedItem? item]) {
    if (item != null) ItemActions.toggleLike(context, item);
  }

  void _startDownload(FeedItem item) => ItemActions.startDownload(context, item);

  Future<void> _startBatchDownload(FeedItem item) =>
      ItemActions.startBatchDownload(context, item);

  Future<void> _onExportPlaylist(FeedItem item) => ItemActions.exportPlaylist(context, item);

  void _showInfo(BuildContext context, FeedItem item) => ItemActions.showInfo(context, item);
  void _showMore(BuildContext context, FeedItem item) => ItemActions.showMore(context, item);

  void _onBatchDelete(FeedItem item) => ItemActions.batchDelete(context, item);

  void _navigateToItem(FeedItem item) => ItemActions.navigateToItem(context, item);

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);

    return BlocListener<SearchBloc, SearchState>(
      listenWhen: (prev, cur) => prev.loading && !cur.loading,
      listener: (_, _) { if (mounted) setState(() => _searching = false); },
      child: BlocBuilder<SearchBloc, SearchState>(builder: (context, state) {
        final showResults = _searchCtrl.text.trim().isNotEmpty;
        final showRecents = !showResults && state.recentSearches.isNotEmpty;

        return Column(children: [
          SizedBox(height: r.spacingM),
          Expanded(
            child: GlassContainer(
              borderRadius: 16,
              borderColor: onBg.withValues(alpha: 0.06),
              bgColor: onBg.withValues(alpha: 0.02),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SearchBarWidget(
                  controller: _searchCtrl,
                  onTextChanged: _onSearchChanged,
                  onClear: _clearSearch,
                  hintText: _searchHint(state),
                  // The source/extension selector lives INSIDE the search bar
                  // (replacing the search icon), so it takes no extra bubble
                  // row. Only the 4 category chips remain as bubbles.
                  sourceTrigger: SourceAccordion(
                    sources: _searchSources(state),
                    selectedSource: _selectedSource,
                    onBg: onBg,
                    glowColor: onBg,
                    onChanged: _onSourceChanged,
                  ),
                ),
                SizedBox(height: r.spacingS),
                SearchTypeChips(
                  selectedType: _selectedType,
                  filters: _filtersFor(state, _selectedSource),
                  onTypeChanged: _onTypeChanged,
                ),
                SizedBox(height: r.spacingXS),
                Expanded(child: BlocSelector<LikeCubit, LikeState, Set<String>>(
                  selector: (ls) => ls.likedFingerprints,
                  builder: (context, likedIds) {
                    return BlocSelector<DownloadCubit, DownloadCubitState, _SearchDlSnap>(
                      selector: (dl) => _SearchDlSnap(
                        dl.downloads.map((k, v) => MapEntry(k, v.state)),
                        dl.downloadedFingerprints,
                      ),
                      builder: (context, dlSnap) {
                        return showResults
                          ? SearchResultsBody(
                              selectedType: _selectedType, selectedSource: _selectedSource, results: state.results,
                              loading: _searching || state.loading, hasSearched: state.hasSearched,
                              error: state.error, likedIds: likedIds,
                              downloadStates: dlSnap.states,
                              downloadedFingerprints: dlSnap.fingerprints,
                              onToggleLike: _toggleLike, onStartDownload: _startDownload, onBatchDownload: _startBatchDownload,
                              onBatchDelete: _onBatchDelete,
                              onExportPlaylist: _onExportPlaylist,
                              onDeleteTrack: (item) => context.read<DownloadCubit>().deleteTrackResolved(item),
                              onShowInfo: _showInfo, onShowMore: _showMore, onNavigateToItem: _navigateToItem,
                            )
                          : showRecents
                              ? SearchRecentList(
                                  searches: state.recentSearches,
                                  onSearchTap: (q) { _searchCtrl.text = q; _onSearchChanged(q); },
                                  onClearAll: () => context.read<SearchBloc>().add(ClearRecentSearches()),
                                  onRemove: (q) => context.read<SearchBloc>().add(RemoveRecentSearch(q)),
                                )
                              : const SearchUrlPaste();
                      },
                    );
                  },
                )),
              ]),
            ),
          ),
        ]);
      }),
    );
  }
}

/// Lightweight snapshot of download states for BlocSelector.
class _SearchDlSnap {
  final Map<String, DownloadState> states;
  final Set<String> fingerprints;
  const _SearchDlSnap(this.states, this.fingerprints);
}


