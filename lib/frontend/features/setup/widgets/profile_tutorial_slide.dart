import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/track_card.dart';
import '../../../shared/widgets/grid_card.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';
import 'profile_tutorial_data.dart';
import 'profile_tutorial_playlist_creator.dart';
import 'profile_tutorial_widgets.dart';

class ProfileTutorialSlide extends StatefulWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const ProfileTutorialSlide({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<ProfileTutorialSlide> createState() => _ProfileTutorialSlideState();
}

class _ProfileTutorialSlideState extends State<ProfileTutorialSlide>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  int _selectedFilter = 0;
  final Set<int> _selectedForPlaylist = {};
  final Set<String> _likedIds = {'song_0', 'song_2', 'playlist_0', 'album_1', 'artist_2'};
  bool _showPlaylistCreator = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  List<DemoItem> get _currentItems {
    switch (_selectedTab) {
      case 0: return demoSongs.toList();
      case 1: return demoPlaylists.toList();
      case 2: return demoAlbums.toList();
      case 3: return demoArtists.toList();
      default: return [];
    }
  }

  void _toggleLike(String id) {
    setState(() { if (_likedIds.contains(id)) { _likedIds.remove(id); } else { _likedIds.add(id); } });
  }

  List<String> get _currentFilters => demoFilterOptions[demoTabs[_selectedTab].type] ?? ['Todos'];

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Padding(
      key: const ValueKey('profileTutorial'),
      padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
      child: Column(children: [
        SizedBox(height: widget.r.spacingM),
        _header(onBg),
        SizedBox(height: widget.r.spacingM),
        Expanded(
          child: GlassContainer(
            borderRadius: 16, borderColor: glowColor.withValues(alpha: 0.15),
            bgColor: onBg.withValues(alpha: 0.02),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _profileSection(onBg, glowColor),
              SizedBox(height: widget.r.spacingS),
              _tabChips(onBg, glowColor),
              SizedBox(height: widget.r.spacingXS),
              _miniSearch(onBg, glowColor),
              SizedBox(height: widget.r.spacingXS),
              _filterChips(onBg, glowColor),
              SizedBox(height: widget.r.spacingS),
              Expanded(child: _contentArea(onBg, glowColor)),
              if (_selectedTab == 1)
                CreatePlaylistButton(
                  showCreator: _showPlaylistCreator,
                  onToggle: () => setState(() => _showPlaylistCreator = !_showPlaylistCreator),
                ),
              SizedBox(height: widget.r.spacingXS),
            ]),
          ),
        ),
        SizedBox(height: widget.r.spacingM),
        _buttons(context, glowColor),
      ]),
    );
  }

  // ── Header ──────────────────────────────────────────────────────

  Widget _header(Color onBg) => ProfileHeader(
    onBg: onBg, r: widget.r,
    title: 'Mi Espacio',
    description: 'Tu espacio personal: filtra canciones, playlists, álbumes o artistas, y crea tus propias listas.',
  );

  // ── Profile ──────────────────────────────────────────────────────

  Widget _profileSection(Color onBg, Color glowColor) => ProfileSection(
    onBg: onBg, glowColor: glowColor, r: widget.r, pulseAnim: _pulseAnim,
    songCount: demoSongs.length, playlistCount: demoPlaylists.length,
  );

  // ── Tabs ─────────────────────────────────────────────────────────

  Widget _tabChips(Color onBg, Color glowColor) => ProfileTabChips(
    selectedIndex: _selectedTab,
    onSelected: (i) => setState(() { _selectedTab = i; _selectedFilter = 0; _showPlaylistCreator = false; }),
    onBg: onBg, glowColor: glowColor, r: widget.r,
  );

  // ── Mini search ─────────────────────────────────────────────────

  Widget _miniSearch(Color onBg, Color glowColor) => ProfileMiniSearch(
    onBg: onBg, glowColor: glowColor, r: widget.r,
    tabLabel: demoTabs[_selectedTab].label.toLowerCase(),
  );

  // ── Filter chips ────────────────────────────────────────────────

  Widget _filterChips(Color onBg, Color glowColor) => ProfileFilterChips(
    selectedIndex: _selectedFilter,
    filters: _currentFilters,
    onSelected: (i) => setState(() => _selectedFilter = i),
    onBg: onBg, glowColor: glowColor, r: widget.r,
  );

  // ── Content area ─────────────────────────────────────────────────

  Widget _contentArea(Color onBg, Color glowColor) {
    if (_showPlaylistCreator && _selectedTab == 1) {
      return PlaylistCreator(
        selectedForPlaylist: _selectedForPlaylist,
        onToggle: (i) => setState(() {
          if (_selectedForPlaylist.contains(i)) { _selectedForPlaylist.remove(i); } else { _selectedForPlaylist.add(i); }
        }),
        onBg: onBg, glowColor: glowColor,
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350), switchInCurve: Curves.easeOutCubic, switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        child: _buildTabContent(onBg, glowColor),
      ),
    );
  }

  Widget _buildTabContent(Color onBg, Color glowColor) {
    final items = _filteredItems();
    if (items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: widget.r.titleSize * 1.5, color: onBg.withValues(alpha: 0.12)),
        SizedBox(height: widget.r.spacingM),
        Text('No hay resultados', style: TextStyle(fontSize: widget.r.footerSize, color: onBg.withValues(alpha: 0.3))),
      ]));
    }
    switch (_selectedTab) {
      case 0: return _songsView(items, onBg, glowColor);
      case 1: return _gridView(items, 'playlist', onBg, glowColor);
      case 2: return _gridView(items, 'album', onBg, glowColor);
      case 3: return _gridView(items, 'artist', onBg, glowColor);
      default: return const SizedBox.shrink();
    }
  }

  List<DemoItem> _filteredItems() {
    final all = _currentItems;
    if (_selectedFilter == 0) return all;
    return all.where((i) => i.tag == _currentFilters[_selectedFilter]).toList();
  }

  // ── Songs / Grid views ──────────────────────────────────────────

  Widget _songsView(List<DemoItem> items, Color onBg, Color glowColor) {
    return ListView(
      key: ValueKey('canciones_$_selectedFilter'),
      padding: EdgeInsets.all(widget.r.spacingS),
      children: items.asMap().entries.map((entry) {
        final i = entry.key; final s = entry.value; final id = 'song_$i';
        return Padding(
          padding: EdgeInsets.only(bottom: widget.r.spacingXS),
          child: TrackCard(
            title: s.title, subtitle: s.artist, coverUrl: s.coverUrl,
            isLiked: _likedIds.contains(id), onLike: () => _toggleLike(id), showDeleteAnimation: true,
            showActions: false,
          ),
        );
      }).toList(),
    );
  }

  Widget _gridView(List<DemoItem> items, String type, Color onBg, Color glowColor) {
    return LayoutBuilder(
      key: ValueKey('${type}_$_selectedFilter'),
      builder: (context, constraints) {
        final avail = constraints.maxWidth - 2 * widget.r.spacingS;
        final crossAxisCount = avail > 700 ? 4 : avail > 380 ? 3 : 2;
        final cardWidth = (avail - (crossAxisCount - 1) * widget.r.spacingXS) / crossAxisCount;
        return SingleChildScrollView(
          padding: EdgeInsets.all(widget.r.spacingS),
          child: Wrap(
            spacing: widget.r.spacingXS, runSpacing: widget.r.spacingS,
            children: items.asMap().entries.map((entry) {
              final i = entry.key; final item = entry.value; final id = '${type}_$i';
              return SizedBox(
                width: cardWidth,
                child: GridCard(
                  type: type, title: item.title, subtitle: item.artist, coverUrl: item.coverUrl,
                  isLiked: _likedIds.contains(id), onLike: () => _toggleLike(id), showDeleteAnimation: true,
                  showActions: false,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Bottom buttons ──────────────────────────────────────────────

  Widget _buttons(BuildContext context, Color glowColor) => ProfileNavButtons(
    glowColor: glowColor,
    backLabel: widget.loc.setup.back,
    continueLabel: widget.loc.setup.continueText,
    onBack: () => context.read<SetupBloc>().add(const PreviousSlide()),
    onContinue: () => context.read<SetupBloc>().add(const NextSlide()),
    r: widget.r,
  );
}

