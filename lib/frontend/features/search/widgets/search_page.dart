import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/models/feed_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/utils/item_actions.dart';
import '../../../shared/constants/source_constants.dart';
import '../../../../backend/services/like_cubit.dart';
import '../../../../backend/services/download_cubit.dart';
import '../../../shared/widgets/glass_container.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';
import 'search_bar_widget.dart';
import 'search_results.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  String _selectedSource = 'deezer';
  String? _selectedType;

  bool _searching = false;

  @override
  void initState() {
    super.initState();
    context.read<SearchBloc>().add(SearchSourceChanged(_selectedSource));
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

  void _performSearch() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    final filterId = _activeFilterId;
    final type = filterId ?? 'all';
    final limit = filterId == null ? 25 : _limitForType(_selectedType!);
    context.read<SearchBloc>().add(
      PerformSearch(query: q, source: _selectedSource, type: type, limit: limit),
    );
  }

  void _onSourceChanged(String src) {
    setState(() {
      _selectedSource = src;
      // Drop a selected category the new source doesn't declare.
      final state = context.read<SearchBloc>().state;
      if (_selectedType != null &&
          !_sourceHasCategory(state, src, _selectedType!)) {
        _selectedType = null;
      }
    });
    context.read<SearchBloc>().add(SearchSourceChanged(src));
    _performSearch();
  }

  void _onTypeChanged(String? t) {
    setState(() => _selectedType = t);
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
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final filterId = _activeFilterId;
      final type = filterId ?? 'all';
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
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

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
              borderColor: glowColor.withValues(alpha: 0.15),
              bgColor: onBg.withValues(alpha: 0.02),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SearchBarWidget(
                  controller: _searchCtrl,
                  selectedSource: _selectedSource,
                  onSourceChanged: _onSourceChanged,
                  onTextChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),
                SizedBox(height: r.spacingS),
                SearchTypeChips(
                  selectedType: _selectedType,
                  filters: _filtersFor(state, _selectedSource),
                  onTypeChanged: _onTypeChanged,
                ),
                SizedBox(height: r.spacingXS),
                Expanded(child: BlocBuilder<LikeCubit, LikeState>(
                  builder: (context, likeState) {
                    return BlocBuilder<DownloadCubit, DownloadCubitState>(
                      builder: (context, dlState) {
                        final ds = <String, DownloadState>{};
                        for (final e in dlState.downloads.entries) {
                          ds[e.key] = e.value.state;
                        }
                        return showResults
                          ? SearchResultsBody(
                              selectedType: _selectedType, results: state.results,
                              loading: _searching || state.loading, hasSearched: state.hasSearched,
                              error: state.error, likedIds: likeState.likedFingerprints,
                              downloadStates: ds,
                              onToggleLike: _toggleLike, onStartDownload: _startDownload,                              onBatchDownload: _startBatchDownload,
                              onBatchDelete: _onBatchDelete,
                              onExportPlaylist: _onExportPlaylist,
                              onDeleteTrack: (item) => context.read<DownloadCubit>().deleteTrackDownload(item.id, item.source ?? ''),
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


