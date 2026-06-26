import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/feed_models.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/helpers/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/track_card.dart';
import '../../../shared/widgets/grid_card.dart';
import '../../../shared/widgets/download_indicator.dart';
import '../../../shared/widgets/song_info_modal.dart';
import '../../../shared/widgets/add_to_modal.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';

const _typeIcons = <String, IconData>{
  'tracks': Icons.music_note,
  'artists': Icons.person,
  'albums': Icons.album,
  'playlists': Icons.playlist_play,
};

const _sourceIcons = <String, IconData>{
  'deezer': Icons.library_music,
  'apple-music': Icons.apple,
  'soundcloud': Icons.cloud_queue,
  'spotify-web': Icons.music_note,
  'pandora': Icons.radio,
  'amazon': Icons.shopping_bag,
  'qobuz-web': Icons.album,
  'tidal-web': Icons.waves,
  'ytmusic-spotiflac': Icons.play_circle_fill,
};

const _allSources = [
  'deezer', 'spotify-web', 'apple-music', 'soundcloud',
  'amazon', 'qobuz-web', 'tidal-web', 'ytmusic-spotiflac',
];

const _sourceLabels = {
  'deezer': 'Deezer',
  'spotify-web': 'Spotify',
  'apple-music': 'Apple Music',
  'soundcloud': 'SoundCloud',
  'pandora': 'Pandora',
  'amazon': 'Amazon Music',
  'qobuz-web': 'Qobuz',
  'tidal-web': 'TIDAL',
  'ytmusic-spotiflac': 'YT Music',
};

const _supportedTypes = <String, List<String>>{
  'tidal-web': ['tracks', 'artists', 'albums', 'playlists'],
  'qobuz-web': ['tracks', 'artists', 'albums'],
  'deezer': ['tracks', 'artists', 'albums', 'playlists'],
  'spotify-web': ['tracks', 'artists', 'albums', 'playlists'],
  'apple-music': ['tracks', 'artists', 'albums', 'playlists'],
  'soundcloud': ['tracks', 'artists', 'albums', 'playlists'],
  'amazon': ['tracks', 'artists', 'albums', 'playlists'],
  'pandora': [],
  'ytmusic-spotiflac': ['tracks', 'artists', 'albums', 'playlists'],
};

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
  final Map<String, double> _downloadProgress = {};
  final Map<String, Timer> _downloadTimers = {};

  @override
  void initState() {
    super.initState();
    _selectedSource = _allSources.first;
    _ensureValidType();
  }

  void _ensureValidType() {
    final types = _supportedTypes[_selectedSource] ?? ['tracks', 'artists', 'albums', 'playlists'];
    if (!types.contains(_selectedType)) {
      _selectedType = types.isNotEmpty ? types.first : 'tracks';
    }
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _hasSearched = false;
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        _performSearch();
      }
    });
  }

  Future<void> _performSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final backend = context.read<SetupBloc>().backend;
      final results = await backend.search(
        query: query,
        source: _selectedSource,
        type: _selectedType == 'tracks' ? 'track'
            : _selectedType == 'artists' ? 'artist'
            : _selectedType == 'albums' ? 'album'
            : 'playlist',
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _hasSearched = true;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _hasSearched = true;
        _searching = false;
      });
    }
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchCtrl.clear();
    setState(() {
      _hasSearched = false;
      _results = [];
      _searching = false;
    });
  }

  void _toggleLike(String id) {
    setState(() {
      if (_likedIds.contains(id)) {
        _likedIds.remove(id);
      } else {
        _likedIds.add(id);
      }
    });
  }

  void _startDownload(String id) {
    if (_downloadStates[id] == DownloadState.inProgress) return;
    setState(() {
      _downloadStates[id] = DownloadState.inProgress;
      _downloadProgress[id] = 0.0;
    });
    const totalSteps = 30;
    const interval = Duration(milliseconds: 100);
    var step = 0;
    _downloadTimers[id]?.cancel();
    _downloadTimers[id] = Timer.periodic(interval, (timer) {
      step++;
      final progress = (step / totalSteps).clamp(0.0, 1.0);
      if (!mounted) { timer.cancel(); return; }
      setState(() => _downloadProgress[id] = progress);
      if (step >= totalSteps) {
        timer.cancel();
        if (!mounted) return;
        setState(() => _downloadStates[id] = DownloadState.completed);
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            _downloadStates.remove(id);
            _downloadProgress.remove(id);
          });
        });
      }
    });
  }

  void _showInfo(BuildContext context, FeedItem item) => showSongInfoModal(context, item);
  void _showMore(BuildContext context, FeedItem item) => showAddToModal(context, item);

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    for (final t in _downloadTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;
    final saving = widget.state.saving;
    final nextOk = widget.state.selectedMode != null && !saving;

    return Padding(
      key: const ValueKey('searchTutorial'),
      padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
      child: Column(children: [
        SizedBox(height: widget.r.spacingM),
        _header(onBg),
        SizedBox(height: widget.r.spacingM),
        Expanded(
          child: GlassContainer(
            borderRadius: 16,
            borderColor: glowColor.withValues(alpha: 0.15),
            bgColor: onBg.withValues(alpha: 0.02),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _searchBar(onBg, glowColor),
              SizedBox(height: widget.r.spacingXS),
              _typeChips(onBg, glowColor),
              SizedBox(height: widget.r.spacingS),
              _sourceBadge(onBg, glowColor),
              SizedBox(height: widget.r.spacingXS),
              Expanded(child: _resultsBody(onBg, glowColor)),
            ]),
          ),
        ),
        SizedBox(height: widget.r.spacingM),
        _buttons(context, glowColor, nextOk, saving),
      ]),
    );
  }

  Widget _header(Color onBg) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: EdgeInsets.all(widget.r.spacingS),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onBg.withValues(alpha: 0.04),
          border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
        ),
        child: Icon(Icons.search, size: widget.r.titleSize * 1.1, color: onBg.withValues(alpha: 0.55)),
      ),
      SizedBox(height: widget.r.spacingS),
      Text(widget.loc.setup.searchTutorialTitle,
        style: TextStyle(fontSize: widget.r.titleSize, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
      SizedBox(height: 2),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
        child: Text(widget.loc.setup.searchTutorialDesc,
          style: TextStyle(fontSize: widget.r.footerSize, color: onBg.withValues(alpha: 0.5)),
          textAlign: TextAlign.center),
      ),
    ]);
  }

  Widget _searchBar(Color onBg, Color glowColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      borderRadius: 12,
      borderColor: onBg.withValues(alpha: 0.1),
      margin: EdgeInsets.fromLTRB(widget.r.spacingS, widget.r.spacingS, widget.r.spacingS, 0),
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingM),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: TextStyle(fontSize: widget.r.subtitleSize, color: onBg),
        decoration: InputDecoration(
          hintText: widget.loc.setup.searchHint,
          hintStyle: TextStyle(fontSize: widget.r.subtitleSize, color: onBg.withValues(alpha: 0.3)),
          border: InputBorder.none,
          icon: _sourceDropdown(isDark, onBg, glowColor),
          suffixIcon: _searchCtrl.text.isNotEmpty
            ? GestureDetector(onTap: _clearSearch,
                child: Icon(Icons.clear, size: widget.r.footerSize + 2, color: onBg.withValues(alpha: 0.3)))
            : null,
        ),
      ),
    );
  }

  Widget _sourceDropdown(bool isDark, Color onBg, Color glowColor) {
    return PopupMenuButton<String>(
      onSelected: (src) {
        setState(() {
          _selectedSource = src;
          _ensureValidType();
        });
        if (_searchCtrl.text.trim().isNotEmpty) {
          _debounceTimer?.cancel();
          _performSearch();
        }
      },
      offset: const Offset(0, 40),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      constraints: BoxConstraints(maxHeight: 320, minWidth: 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_sourceIcons[_selectedSource] ?? Icons.search,
            size: widget.r.footerSize + 2, color: glowColor.withValues(alpha: 0.7)),
          Icon(Icons.arrow_drop_down, size: widget.r.footerSize, color: onBg.withValues(alpha: 0.4)),
        ],
      ),
      itemBuilder: (_) => _allSources.map((src) {
        final sel = src == _selectedSource;
        return PopupMenuItem<String>(
          value: src,
          height: 36,
          child: Row(
            children: [
              Icon(
                _sourceIcons[src] ?? Icons.music_video,
                size: widget.r.footerSize,
                color: sel ? glowColor : onBg.withValues(alpha: 0.5),
              ),
              SizedBox(width: widget.r.spacingXS),
              Expanded(
                child: Text(
                  _sourceLabels[src] ?? _formatId(src),
                  style: TextStyle(
                    fontSize: widget.r.footerSize - 1,
                    color: sel ? glowColor : onBg.withValues(alpha: 0.7),
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (sel)
                Icon(Icons.check, size: widget.r.footerSize - 2, color: glowColor),
            ],
          ),
        );
      }).toList(),
    );
  }

  static String _formatId(String id) => id
    .replaceAll('-', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');

  List<String> get _availableTypes => _supportedTypes[_selectedSource] ?? ['tracks', 'artists', 'albums', 'playlists'];

  Widget _typeChips(Color onBg, Color glowColor) {
    final types = _availableTypes;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingS),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: types.map((t) {
          final sel = _selectedType == t;
          return Padding(
            padding: EdgeInsets.only(right: widget.r.spacingXS),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedType = t);
                if (_searchCtrl.text.trim().isNotEmpty) {
                  _debounceTimer?.cancel();
                  _performSearch();
                }
              },
              child: GlassContainer(
                borderRadius: 20,
                borderColor: sel ? glowColor : onBg.withValues(alpha: 0.1),
                bgColor: sel ? glowColor.withValues(alpha: 0.15) : Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: widget.r.spacingM, vertical: widget.r.spacingXS),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_typeIcons[t] ?? Icons.search, size: widget.r.footerSize,
                    color: sel ? glowColor : onBg.withValues(alpha: 0.5)),
                  SizedBox(width: widget.r.spacingXS),
                  Text(t == 'tracks' ? widget.loc.setup.searchTracks
                    : t == 'artists' ? widget.loc.setup.searchArtists
                    : t == 'albums' ? widget.loc.setup.searchAlbums
                    : widget.loc.setup.searchPlaylists,
                    style: TextStyle(fontSize: widget.r.footerSize,
                      color: sel ? glowColor : onBg.withValues(alpha: 0.5), fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                ]),
              ),
            ),
          );
        }).toList()),
      ),
    );
  }

  Widget _sourceBadge(Color onBg, Color glowColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingS),
      child: Row(
        children: [
          Icon(_sourceIcons[_selectedSource] ?? Icons.search,
            size: widget.r.footerSize, color: glowColor.withValues(alpha: 0.6)),
          SizedBox(width: 4),
          Text(_sourceLabels[_selectedSource] ?? _formatId(_selectedSource),
            style: TextStyle(
              fontSize: widget.r.footerSize - 1,
              color: onBg.withValues(alpha: 0.4),
            )),
          SizedBox(width: 8),
          // Quick-cycle button: tap to go to next source
          GestureDetector(
            onTap: () {
              final idx = _allSources.indexOf(_selectedSource);
              final next = _allSources[(idx + 1) % _allSources.length];
              setState(() {
                _selectedSource = next;
                _ensureValidType();
              });
              if (_searchCtrl.text.trim().isNotEmpty) {
                _debounceTimer?.cancel();
                _performSearch();
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: glowColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_sourceLabels[_allSources[(_allSources.indexOf(_selectedSource) + 1) % _allSources.length]] ?? '',
                    style: TextStyle(fontSize: widget.r.footerSize - 2, color: glowColor.withValues(alpha: 0.6))),
                  SizedBox(width: 2),
                  Icon(Icons.swap_horiz, size: widget.r.footerSize - 2, color: glowColor.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsBody(Color onBg, Color glowColor) {
    if (_searchCtrl.text.trim().isEmpty && !_hasSearched) {
      return _urlPasteArea(onBg, glowColor);
    }
    if (_searching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.r.footerSize + 4,
              height: widget.r.footerSize + 4,
              child: CircularProgressIndicator(strokeWidth: 2, color: glowColor),
            ),
            SizedBox(height: widget.r.spacingS),
            Text('Buscando...',
              style: TextStyle(fontSize: widget.r.footerSize, color: onBg.withValues(alpha: 0.4))),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(widget.loc.setup.feedEmpty,
          style: TextStyle(fontSize: widget.r.footerSize, color: onBg.withValues(alpha: 0.4))),
      );
    }
    final isTrackType = _selectedType == 'tracks';
    if (isTrackType) {
      return ListView(
        padding: EdgeInsets.all(widget.r.spacingS),
        children: _results.map((item) {
          final id = '${item.type}_${item.id}_${item.source}';
          return Padding(
            padding: EdgeInsets.only(bottom: widget.r.spacingXS),
            child: TrackCard(
              title: item.name, subtitle: item.artists ?? '', coverUrl: item.coverUrl,
              isLiked: _likedIds.contains(id), onLike: () => _toggleLike(id),
              downloadState: _downloadStates[id] ?? DownloadState.none,
              downloadProgress: _downloadProgress[id] ?? 0.0,
              onDownload: () => _startDownload(id),
              onInfo: () => _showInfo(context, item),
              onMore: () => _showMore(context, item),
            ),
          );
        }).toList(),
      );
    }
    // Albums/artists/playlists: responsive grid that fills width
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth - 2 * widget.r.spacingS;
        final crossAxisCount = avail > 700 ? 4 : avail > 340 ? 3 : 2;
        final gap = widget.r.spacingXS;
        final cardWidth = (avail - (crossAxisCount - 1) * gap) / crossAxisCount;

        return SingleChildScrollView(
          padding: EdgeInsets.all(widget.r.spacingS),
          child: Wrap(
            spacing: gap,
            runSpacing: widget.r.spacingXS,
            children: _results.map((item) {
              final id = '${item.type}_${item.id}_${item.source}';
              return SizedBox(
                width: cardWidth,
                child: GridCard(
                  type: item.type, title: item.name, subtitle: item.artists ?? '', coverUrl: item.coverUrl,
                  isLiked: _likedIds.contains(id), onLike: () => _toggleLike(id),
                  downloadState: _downloadStates[id] ?? DownloadState.none,
                  downloadProgress: _downloadProgress[id] ?? 0.0,
                  onDownload: () => _startDownload(id),
                  onMore: () => _showMore(context, item),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _urlPasteArea(Color onBg, Color glowColor) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(widget.r.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: widget.r.titleSize * 1.5, color: onBg.withValues(alpha: 0.15)),
            SizedBox(height: widget.r.spacingM),
            Text(widget.loc.setup.searchPasteHint,
              style: TextStyle(fontSize: widget.r.footerSize, color: onBg.withValues(alpha: 0.4)),
              textAlign: TextAlign.center),
            SizedBox(height: widget.r.spacingM),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _urlBadge(Icons.play_circle_fill, 'YouTube', glowColor, onBg),
                SizedBox(width: widget.r.spacingS),
                _urlBadge(Icons.music_note, 'Spotify', glowColor, onBg),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _urlBadge(IconData icon, String label, Color glowColor, Color onBg) {
    return GlassContainer(
      borderRadius: 20,
      borderColor: glowColor.withValues(alpha: 0.2),
      bgColor: glowColor.withValues(alpha: 0.06),
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingM, vertical: widget.r.spacingXS),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: widget.r.footerSize, color: glowColor),
        SizedBox(width: widget.r.spacingXS),
        Text(label, style: TextStyle(fontSize: widget.r.footerSize, color: glowColor, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buttons(BuildContext context, Color glowColor, bool nextOk, bool saving) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
      child: SizedBox(
        height: widget.r.continueButtonHeight,
        child: Row(children: [
          Expanded(child: GlassButton(
            label: widget.loc.setup.back,
            onPressed: () => context.read<SetupBloc>().add(const PreviousSlide()),
            height: widget.r.continueButtonHeight, accent: glowColor)),
          SizedBox(width: widget.r.spacingM),
          Expanded(child: GlassButton(
            label: widget.loc.setup.continueText,
            onPressed: nextOk
                ? () => context.read<SetupBloc>().add(const NextSlide())
                : null,
            isLoading: saving, height: widget.r.continueButtonHeight, accent: glowColor)),
          ]),
      ),
    );
  }
}
