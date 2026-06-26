import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/helpers/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/track_card.dart';
import '../../../shared/widgets/grid_card.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sample data
// ─────────────────────────────────────────────────────────────────────────────

// Real Deezer CDN album cover URLs (250x250)
// Real Deezer CDN album cover URLs (250x250) from api.deezer.com
const _uvstCover =
    'https://cdn-images.dzcdn.net/images/cover/b29d1070377b784384c2456093f96a66/250x250-000000-80-0-0.jpg';
const _yhlqmdlgCover =
    'https://cdn-images.dzcdn.net/images/cover/0a6f32569d4785c5ef82f581086f4302/250x250-000000-80-0-0.jpg';
const _eltourCover =
    'https://cdn-images.dzcdn.net/images/cover/6ea80078f0df08737a7471f3c4cf2afa/250x250-000000-80-0-0.jpg';
// Real Deezer CDN artist images (250x250)
const _badBunnyArtist =
    'https://cdn-images.dzcdn.net/images/artist/044a3f315b041864887a8dd8709e6926/250x250-000000-80-0-0.jpg';
const _rauwArtist =
    'https://cdn-images.dzcdn.net/images/artist/0e7b2b93b91789a054bc3f08bb3df3a8/250x250-000000-80-0-0.jpg';
const _jbalvinArtist =
    'https://cdn-images.dzcdn.net/images/artist/325eaa46bc25052d0e3d549d60cc8225/250x250-000000-80-0-0.jpg';
// Real Deezer playlist covers
const _playlistVerano =
    'https://cdn-images.dzcdn.net/images/playlist/19968a720110493a0496dfe8a1b7013d/250x250-000000-80-0-0.jpg';
const _playlistFavs =
    'https://cdn-images.dzcdn.net/images/cover/6c9a6046dc369375ee5181480bcc4962-e0dd8263dfed37c50a868abbf65fd7da-d74bc3362822f21125e1bc5778e3cd13-891aea0a33f3ff28912187a50cb94738/250x250-000000-80-0-0.jpg';
const _playlistGym =
    'https://cdn-images.dzcdn.net/images/playlist/5f55d4c9033ff8e3b4bf5aa9f40c99d1/250x250-000000-80-0-0.jpg';

const _songs = [
  _DemoItem('Dákiti', 'Bad Bunny', _ItemType.song, 'Recién',
      coverUrl: _eltourCover),
  _DemoItem('Monaco', 'Bad Bunny', _ItemType.song, 'Favoritas',
      coverUrl: _uvstCover),
  _DemoItem('Tití Me Preguntó', 'Bad Bunny', _ItemType.song, 'Recién',
      coverUrl: _uvstCover),
  _DemoItem('Neverita', 'Bad Bunny', _ItemType.song, 'Descargadas',
      coverUrl: _uvstCover),
  _DemoItem('Efecto', 'Bad Bunny', _ItemType.song, 'Descargadas',
      coverUrl: _uvstCover),
  _DemoItem('Ojitos Lindos', 'Bad Bunny', _ItemType.song, 'Favoritas',
      coverUrl: _uvstCover),
  _DemoItem('Me Porto Bonito', 'Bad Bunny', _ItemType.song, 'Recién',
      coverUrl: _uvstCover),
  _DemoItem('Un Verano Sin Ti', 'Bad Bunny', _ItemType.song, 'Escuchadas',
      coverUrl: _uvstCover),
];

const _playlists = [
  _DemoItem('Verano Hits', '8 canciones', _ItemType.playlist, 'Creadas',
      coverUrl: _playlistVerano),
  _DemoItem('Favoritas 2026', '12 canciones', _ItemType.playlist, 'Creadas',
      coverUrl: _playlistFavs),
  _DemoItem('Para Gym', '20 canciones', _ItemType.playlist, 'Guardadas',
      coverUrl: _playlistGym),
];

const _albums = [
  _DemoItem('Un Verano Sin Ti', 'Bad Bunny · 2022', _ItemType.album, 'Completos',
      coverUrl: _uvstCover),
  _DemoItem('YHLQMDLG', 'Bad Bunny · 2020', _ItemType.album, 'Completos',
      coverUrl: _yhlqmdlgCover),
  _DemoItem('El Último Tour', 'Bad Bunny · 2020', _ItemType.album, 'Pendientes',
      coverUrl: _eltourCover),
];

const _artists = [
  _DemoItem('Bad Bunny', '8 canciones', _ItemType.artist, 'Seguidos',
      coverUrl: _badBunnyArtist),
  _DemoItem('Rauw Alejandro', '3 canciones', _ItemType.artist, 'Seguidos',
      coverUrl: _rauwArtist),
  _DemoItem('J Balvin', '5 canciones', _ItemType.artist, 'Populares',
      coverUrl: _jbalvinArtist),
];

enum _ItemType { song, playlist, album, artist }

// ─────────────────────────────────────────────────────────────────────────────
// Type definitions
// ─────────────────────────────────────────────────────────────────────────────

class _TabDef {
  final String label;
  final IconData icon;
  final _ItemType type;
  const _TabDef(this.label, this.icon, this.type);
}

const _tabs = [
  _TabDef('Canciones', Icons.music_note, _ItemType.song),
  _TabDef('Playlists', Icons.queue_music, _ItemType.playlist),
  _TabDef('Álbumes', Icons.album, _ItemType.album),
  _TabDef('Artistas', Icons.person, _ItemType.artist),
];

const _filterOptions = <_ItemType, List<String>>{
  _ItemType.song: ['Todas', 'Recién', 'Favoritas', 'Descargadas', 'Escuchadas'],
  _ItemType.playlist: ['Todas', 'Creadas', 'Guardadas'],
  _ItemType.album: ['Todos', 'Completos', 'Pendientes'],
  _ItemType.artist: ['Todos', 'Seguidos', 'Populares'],
};

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

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
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  List<_DemoItem> get _currentItems {
    switch (_selectedTab) {
      case 0: return _songs.toList();
      case 1: return _playlists.toList();
      case 2: return _albums.toList();
      case 3: return _artists.toList();
      default: return [];
    }
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

  List<String> get _currentFilters =>
      _filterOptions[_tabs[_selectedTab].type] ?? ['Todos'];

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
            borderRadius: 16,
            borderColor: glowColor.withValues(alpha: 0.15),
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
              _createPlaylistButton(onBg, glowColor),
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

  Widget _header(Color onBg) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: EdgeInsets.all(widget.r.spacingS),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onBg.withValues(alpha: 0.04),
          border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
        ),
        child: Icon(Icons.library_music_outlined,
          size: widget.r.titleSize * 1.1,
          color: onBg.withValues(alpha: 0.55)),
      ),
      SizedBox(height: widget.r.spacingS),
      Text('Tu Biblioteca',
        style: TextStyle(
          fontSize: widget.r.titleSize,
          fontWeight: FontWeight.bold,
          color: onBg,
          letterSpacing: 1)),
      SizedBox(height: 2),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
        child: Text('Administra tu biblioteca personal: filtra canciones, playlists, álbumes o artistas, y crea tus propias listas.',
          style: TextStyle(
            fontSize: widget.r.footerSize,
            color: onBg.withValues(alpha: 0.5)),
          textAlign: TextAlign.center),
      ),
    ]);
  }

  // ── Profile ──────────────────────────────────────────────────────

  Widget _profileSection(Color onBg, Color glowColor) {
    final avatarSize = widget.r.titleSize * 2.2;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.r.spacingL, widget.r.spacingM, widget.r.spacingL, 0),
      child: Row(children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnim.value,
            child: child,
          ),
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  glowColor.withValues(alpha: 0.35),
                  glowColor.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: glowColor.withValues(alpha: 0.45),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.person,
              size: avatarSize * 0.45,
              color: onBg.withValues(alpha: 0.5)),
          ),
        ),
        SizedBox(width: widget.r.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bad Bunny Fan',
                style: TextStyle(
                  fontSize: widget.r.subtitleSize,
                  fontWeight: FontWeight.w600,
                  color: onBg)),
              SizedBox(height: 2),
              Text('${_songs.length} canciones  •  ${_playlists.length} playlists',
                style: TextStyle(
                  fontSize: widget.r.footerSize - 1,
                  color: onBg.withValues(alpha: 0.4))),
            ]),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.r.spacingS, vertical: 4),
          decoration: BoxDecoration(
            color: glowColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.headphones,
              size: widget.r.footerSize, color: glowColor),
            SizedBox(width: 4),
            Text('42 min',
              style: TextStyle(
                fontSize: widget.r.footerSize - 1,
                fontWeight: FontWeight.w600,
                color: glowColor)),
          ]),
        ),
      ]),
    );
  }

  // ── 4 type tabs ──────────────────────────────────────────────────

  Widget _tabChips(Color onBg, Color glowColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingS),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(_tabs.length, (i) {
          final t = _tabs[i];
          final sel = _selectedTab == i;
          return Padding(
            padding: EdgeInsets.only(right: widget.r.spacingXS),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedTab = i;
                _selectedFilter = 0;
                _showPlaylistCreator = false;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: sel
                    ? glowColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                  border: Border.all(
                    color: sel
                      ? glowColor.withValues(alpha: 0.5)
                      : onBg.withValues(alpha: 0.1),
                    width: sel ? 1.0 : 0.6,
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.r.spacingM,
                  vertical: widget.r.spacingXS),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.icon,
                    size: widget.r.footerSize + 1,
                    color: sel
                      ? glowColor
                      : onBg.withValues(alpha: 0.45)),
                  SizedBox(width: widget.r.spacingXS),
                  Text(t.label,
                    style: TextStyle(
                      fontSize: widget.r.footerSize,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      color: sel
                        ? glowColor
                        : onBg.withValues(alpha: 0.45))),
                ]),
              ),
            ),
          );
        })),
      ),
    );
  }

  // ── Mini search bar ─────────────────────────────────────────────

  Widget _miniSearch(Color onBg, Color glowColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingS),
      child: GlassContainer(
        borderRadius: 10,
        borderColor: onBg.withValues(alpha: 0.08),
        padding: EdgeInsets.symmetric(horizontal: widget.r.spacingM),
        child: Row(children: [
          Icon(Icons.search_rounded,
            size: widget.r.footerSize + 2,
            color: onBg.withValues(alpha: 0.3)),
          SizedBox(width: widget.r.spacingXS),
          Expanded(
            child: TextField(
              enabled: false,
              style: TextStyle(
                fontSize: widget.r.footerSize,
                color: onBg),
              decoration: InputDecoration(
                hintText: 'Buscar en ${_tabs[_selectedTab].label.toLowerCase()}...',
                hintStyle: TextStyle(
                  fontSize: widget.r.footerSize,
                  color: onBg.withValues(alpha: 0.25)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: glowColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.tune,
              size: widget.r.footerSize - 2,
              color: glowColor.withValues(alpha: 0.6)),
          ),
        ]),
      ),
    );
  }

  // ── Filter chips ────────────────────────────────────────────────

  Widget _filterChips(Color onBg, Color glowColor) {
    final filters = _currentFilters;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingS),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(filters.length, (i) {
          final f = filters[i];
          final sel = _selectedFilter == i;
          return Padding(
            padding: EdgeInsets.only(right: widget.r.spacingXS),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: sel
                    ? glowColor.withValues(alpha: 0.12)
                    : onBg.withValues(alpha: 0.04),
                  border: Border.all(
                    color: sel
                      ? glowColor.withValues(alpha: 0.3)
                      : onBg.withValues(alpha: 0.06),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.r.spacingM,
                  vertical: 4),
                child: Text(f,
                  style: TextStyle(
                    fontSize: widget.r.footerSize - 1,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    color: sel
                      ? glowColor
                      : onBg.withValues(alpha: 0.4))),
              ),
            ),
          );
        })),
      ),
    );
  }

  // ── Content area ─────────────────────────────────────────────────

  Widget _contentArea(Color onBg, Color glowColor) {
    if (_showPlaylistCreator && _selectedTab == 1) {
      return _playlistCreator(onBg, glowColor);
    }
    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: _buildTabContent(onBg, glowColor),
      ),
    );
  }

  Widget _buildTabContent(Color onBg, Color glowColor) {
    final items = _filteredItems();
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
              size: widget.r.titleSize * 1.5,
              color: onBg.withValues(alpha: 0.12)),
            SizedBox(height: widget.r.spacingM),
            Text('No hay resultados',
              style: TextStyle(
                fontSize: widget.r.footerSize,
                color: onBg.withValues(alpha: 0.3))),
          ],
        ),
      );
    }

    switch (_selectedTab) {
      case 0: return _songsView(items, onBg, glowColor);
      case 1: return _gridView(items, 'playlist', onBg, glowColor);
      case 2: return _gridView(items, 'album', onBg, glowColor);
      case 3: return _gridView(items, 'artist', onBg, glowColor);
      default: return const SizedBox.shrink();
    }
  }

  List<_DemoItem> _filteredItems() {
    final all = _currentItems;
    final filter = _selectedFilter;
    if (filter == 0) return all; // "Todas"/"Todos"
    final label = _currentFilters[filter];
    return all.where((i) => i.tag == label).toList();
  }

  // ── Songs view ──────────────────────────────────────────────────

  Widget _songsView(List<_DemoItem> items, Color onBg, Color glowColor) {
    return ListView(
      key: ValueKey('canciones_$_selectedFilter'),
      padding: EdgeInsets.all(widget.r.spacingS),
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        final id = 'song_$i';
        return Padding(
          padding: EdgeInsets.only(bottom: widget.r.spacingXS),
          child: TrackCard(
            title: s.title,
            subtitle: s.artist,
            coverUrl: s.coverUrl,
            isLiked: _likedIds.contains(id),
            onLike: () => _toggleLike(id),
            showDeleteAnimation: true,
          ),
        );
      }).toList(),
    );
  }

  // ── Grid view (playlists, albums, artists) ──────────────────────

  Widget _gridView(List<_DemoItem> items, String type,
      Color onBg, Color glowColor) {
    return LayoutBuilder(
      key: ValueKey('${type}_$_selectedFilter'),
      builder: (context, constraints) {
        final avail = constraints.maxWidth - 2 * widget.r.spacingS;
        final crossAxisCount = avail > 700 ? 4 : avail > 380 ? 3 : 2;
        final gap = widget.r.spacingXS;
        final cardWidth = (avail - (crossAxisCount - 1) * gap) / crossAxisCount;

        return SingleChildScrollView(
          padding: EdgeInsets.all(widget.r.spacingS),
          child: Wrap(
            spacing: gap,
            runSpacing: widget.r.spacingS,
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final id = '${type}_$i';
              return SizedBox(
                width: cardWidth,
                child: GridCard(
                  type: type,
                  title: item.title,
                  subtitle: item.artist,
                  coverUrl: item.coverUrl,
                  isLiked: _likedIds.contains(id),
                  onLike: () => _toggleLike(id),
                  showDeleteAnimation: true,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Playlist creator ─────────────────────────────────────────────

  Widget _createPlaylistButton(Color onBg, Color glowColor) {
    // Only show on playlists tab
    if (_selectedTab != 1) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingS),
      child: GestureDetector(
        onTap: () => setState(
            () => _showPlaylistCreator = !_showPlaylistCreator),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _showPlaylistCreator
              ? glowColor.withValues(alpha: 0.1)
              : onBg.withValues(alpha: 0.03),
            border: Border.all(
              color: _showPlaylistCreator
                ? glowColor.withValues(alpha: 0.4)
                : onBg.withValues(alpha: 0.1),
              width: _showPlaylistCreator ? 1.0 : 0.6,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.r.spacingM,
            vertical: widget.r.spacingS),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _showPlaylistCreator
                    ? Icons.check_circle_outline
                    : Icons.playlist_add,
                  key: ValueKey(_showPlaylistCreator),
                  size: widget.r.footerSize + 2,
                  color: _showPlaylistCreator
                    ? glowColor
                    : onBg.withValues(alpha: 0.55)),
              ),
              SizedBox(width: widget.r.spacingS),
              Text(
                _showPlaylistCreator
                  ? 'Confirmar playlist'
                  : 'Crear playlist',
                style: TextStyle(
                  fontSize: widget.r.footerSize,
                  fontWeight: FontWeight.w600,
                  color: _showPlaylistCreator
                    ? glowColor
                    : onBg.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playlistCreator(Color onBg, Color glowColor) {
    return ListView(
      key: const ValueKey('playlistCreator'),
      padding: EdgeInsets.all(widget.r.spacingS),
      children: [
        Row(children: [
          Icon(Icons.playlist_add_check,
            size: widget.r.footerSize, color: glowColor),
          SizedBox(width: widget.r.spacingXS),
          Text('Selecciona canciones',
            style: TextStyle(
              fontSize: widget.r.subtitleSize,
              fontWeight: FontWeight.w600,
              color: onBg)),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.symmetric(
              horizontal: widget.r.spacingS, vertical: 2),
            decoration: BoxDecoration(
              color: _selectedForPlaylist.isNotEmpty
                ? glowColor.withValues(alpha: 0.15)
                : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_selectedForPlaylist.length} seleccionadas',
              style: TextStyle(
                fontSize: widget.r.footerSize - 1,
                color: _selectedForPlaylist.isNotEmpty
                  ? glowColor
                  : onBg.withValues(alpha: 0.35),
                fontWeight: _selectedForPlaylist.isNotEmpty
                  ? FontWeight.w600 : FontWeight.normal)),
          ),
        ]),
        SizedBox(height: widget.r.spacingS),
        ..._songs.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final sel = _selectedForPlaylist.contains(i);
          return Padding(
            padding: EdgeInsets.only(bottom: widget.r.spacingXS),
            child: GestureDetector(
              onTap: () => setState(() {
                if (sel) {
                  _selectedForPlaylist.remove(i);
                } else {
                  _selectedForPlaylist.add(i);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: sel
                      ? glowColor.withValues(alpha: 0.4)
                      : onBg.withValues(alpha: 0.08),
                    width: sel ? 1.2 : 0.6,
                  ),
                  color: sel
                    ? glowColor.withValues(alpha: 0.08)
                    : Colors.transparent,
                ),
                padding: EdgeInsets.all(widget.r.spacingS),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? glowColor : Colors.transparent,
                      border: Border.all(
                        color: sel ? glowColor : onBg.withValues(alpha: 0.25),
                        width: sel ? 0 : 1.5,
                      ),
                    ),
                    child: sel
                      ? Icon(Icons.check, size: 14, color: Colors.black)
                      : null,
                  ),
                  SizedBox(width: widget.r.spacingM),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: glowColor.withValues(alpha: 0.1),
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                        style: TextStyle(
                          fontSize: widget.r.footerSize,
                          fontWeight: FontWeight.w700,
                          color: glowColor.withValues(alpha: 0.7))),
                    ),
                  ),
                  SizedBox(width: widget.r.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                          style: TextStyle(
                            fontSize: widget.r.footerSize + 1,
                            fontWeight: FontWeight.w600,
                            color: onBg),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                        Text(s.artist,
                          style: TextStyle(
                            fontSize: widget.r.footerSize - 2,
                            color: onBg.withValues(alpha: 0.4)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: glowColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s.tag,
                      style: TextStyle(
                        fontSize: widget.r.footerSize - 3,
                        fontWeight: FontWeight.w500,
                        color: glowColor.withValues(alpha: 0.6)),
                    ),
                  ),
                ]),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Bottom buttons ──────────────────────────────────────────────

  Widget _buttons(BuildContext context, Color glowColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
      child: SizedBox(
        height: widget.r.continueButtonHeight,
        child: Row(children: [
          Expanded(child: GlassButton(
            label: widget.loc.setup.back,
            onPressed: () =>
              context.read<SetupBloc>().add(const PreviousSlide()),
            height: widget.r.continueButtonHeight,
            accent: glowColor)),
          SizedBox(width: widget.r.spacingM),
          Expanded(child: GlassButton(
            label: widget.loc.setup.continueText,
            onPressed: () =>
              context.read<SetupBloc>().add(const NextSlide()),
            height: widget.r.continueButtonHeight,
            accent: glowColor)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Demo item model
// ─────────────────────────────────────────────────────────────────────────────

class _DemoItem {
  final String title;
  final String artist;
  final _ItemType type;
  final String tag;
  final String? coverUrl;
  const _DemoItem(this.title, this.artist, this.type, this.tag, {this.coverUrl});
}
