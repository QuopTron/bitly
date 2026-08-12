import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/feed_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/download_indicator.dart';
import 'search_tutorial_data.dart';
import 'search_tutorial_widgets.dart';
import '../../../shared/constants/source_constants.dart';
import '../../../../backend/rpc/backend_service.dart';
import '../../../../injection.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';

class SearchTutorialSlide extends StatefulWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const SearchTutorialSlide({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<SearchTutorialSlide> createState() => _SearchTutorialSlideState();
}

class _SearchTutorialSlideState extends State<SearchTutorialSlide> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedSource = '';
  String _selectedType = 'tracks';
  Timer? _debounceTimer;
  bool _searching = false;
  List<FeedItem> _results = [];
  bool _hasSearched = false;

  final Set<String> _likedIds = {};
  final Map<String, DownloadState> _downloadStates = {};

  @override
  void initState() {
    super.initState();
    _selectedSource = allSources.first;
    _ensureValidType();
  }

  void _ensureValidType() {
    final types = supportedTypes[_selectedSource] ?? ['tracks', 'artists', 'albums', 'playlists'];
    if (!types.contains(_selectedType)) {
      _selectedType = types.isNotEmpty ? types.first : 'tracks';
    }
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    if (text.trim().isEmpty) {
      setState(() { _hasSearched = false; _results = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final backend = sl<BackendService>();
      final resultType = _selectedType == 'tracks' ? 'track'
        : _selectedType == 'artists' ? 'artist'
        : _selectedType == 'albums' ? 'album' : 'playlist';
      final results = await backend.search(query: query, source: _selectedSource, type: resultType, limit: 20);
      if (!mounted) return;
      setState(() { _results = results; _hasSearched = true; _searching = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _results = []; _hasSearched = true; _searching = false; });
    }
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchCtrl.clear();
    setState(() { _hasSearched = false; _results = []; _searching = false; });
  }

  void _onSourceChanged(String src) {
    setState(() { _selectedSource = src; _ensureValidType(); });
    if (_searchCtrl.text.trim().isNotEmpty) {
      _debounceTimer?.cancel();
      _performSearch();
    }
  }

  void _onTypeChanged(String t) {
    setState(() => _selectedType = t);
    if (_searchCtrl.text.trim().isNotEmpty) {
      _debounceTimer?.cancel();
      _performSearch();
    }
  }

  void _toggleLike(String id) {
    // No-op: tutorial preview only
  }

  void _startDownload(String id) {
    // No-op: tutorial preview only
  }

  void _showInfo(BuildContext context, FeedItem item) {
    // No-op: tutorial preview only
  }

  void _showMore(BuildContext context, FeedItem item) {
    // No-op: tutorial preview only
  }

  List<String> get _availableTypes => supportedTypes[_selectedSource] ?? ['tracks', 'artists', 'albums', 'playlists'];

  String _typeLabel(String t) => t == 'tracks' ? widget.loc.setup.searchTracks
    : t == 'artists' ? widget.loc.setup.searchArtists
    : t == 'albums' ? widget.loc.setup.searchAlbums
    : widget.loc.setup.searchPlaylists;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;
    final saving = widget.state.saving;
    final nextOk = widget.state.selectedMode != null && !saving;
    final loc = widget.loc;
    final r = widget.r;
    final isDark = widget.isDark;

    return Padding(
      key: const ValueKey('searchTutorial'),
      padding: EdgeInsets.only(bottom: r.bottomPadding),
      child: Column(children: [
        SizedBox(height: r.spacingM),
        TutorialHeader(onBg: onBg, title: loc.setup.searchTutorialTitle, description: loc.setup.searchTutorialDesc),
        SizedBox(height: r.spacingM),
        Expanded(
          child: GlassContainer(
            borderRadius: 16,
            borderColor: glowColor.withValues(alpha: 0.15),
            bgColor: onBg.withValues(alpha: 0.02),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SearchTutorialBar(
                controller: _searchCtrl,
                onBg: onBg,
                glowColor: glowColor,
                hintText: loc.setup.searchHint,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
                leading: SourceDropdown(
                  selectedSource: _selectedSource,
                  onSelected: _onSourceChanged,
                  isDark: isDark,
                  onBg: onBg,
                  glowColor: glowColor,
                ),
              ),
              SizedBox(height: r.spacingXS),
              TypeChipsRow(
                selectedType: _selectedType,
                types: _availableTypes,
                onSelected: _onTypeChanged,
                onBg: onBg,
                glowColor: glowColor,
                labelBuilder: _typeLabel,
              ),
              SizedBox(height: r.spacingS),
              SourceBadge(selectedSource: _selectedSource, onBg: onBg, glowColor: glowColor),
              SizedBox(height: r.spacingXS),
              Expanded(child: _buildResults(onBg, glowColor, loc)),
            ]),
          ),
        ),
        SizedBox(height: r.spacingM),
        TutorialNavButtons(
          glowColor: glowColor,
          nextOk: nextOk,
          saving: saving,
          backLabel: loc.setup.back,
          continueLabel: loc.setup.continueText,
          onBack: () => context.read<SetupBloc>().add(const PreviousSlide()),
          onContinue: () => context.read<SetupBloc>().add(const NextSlide()),
        ),
      ]),
    );
  }

  Widget _buildResults(Color onBg, Color glowColor, AppLocalizations loc) {
    if (_searchCtrl.text.trim().isEmpty && !_hasSearched) {
      return TutorialUrlPaste(onBg: onBg, glowColor: glowColor, pasteHint: loc.setup.searchPasteHint);
    }
    return SearchResultsView(
      results: _results,
      selectedType: _selectedType,
      searching: _searching,
      likedIds: _likedIds,
      downloadStates: _downloadStates,
      onToggleLike: _toggleLike,
      onDownload: _startDownload,
      onShowInfo: _showInfo,
      onShowMore: _showMore,
      onBg: onBg,
      glowColor: glowColor,
      searchingLabel: loc.setup.searching,
      emptyLabel: loc.setup.feedEmpty,
    );
  }
}

