import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../models/download_settings.dart';
import '../models/premium_status.dart';
import '../../../backend/cache/playback_cache.dart';
import '../../../backend/cache/premium_cache.dart';
import '../../../backend/cache/settings_cache.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../backend/services/premium_service.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../config/secrets.dart';
import '../../../injection.dart';
import 'glass_container.dart';
import 'settings_sections.dart';
import 'settings_cache_section.dart';
import 'settings_performance_section.dart';
import 'settings_stats.dart';
import 'update_modal.dart';
import '../utils/cover_palette.dart';
import 'cover_image.dart' show imageFromUrl;

/// Reacts to the current queue + playback: when a track is loaded (and has a
/// cover) the sheet gets tinted with the cover's dominant color via a blurred
/// ambient backdrop; when playback stops / queue empties it fades back to the
/// theme's default surface. Colors animate so the transition is smooth.
class _SongTintedBackground extends StatefulWidget {
  final QueueState queue;
  final bool isDark;
  final Color defaultBg;
  final Widget child;

  const _SongTintedBackground({
    super.key,
    required this.queue,
    required this.isDark,
    required this.defaultBg,
    required this.child,
  });

  @override
  State<_SongTintedBackground> createState() => _SongTintedBackgroundState();
}

class _SongTintedBackgroundState extends State<_SongTintedBackground> {
  Color _bg = const Color(0xFF000000);
  String? _cover;
  bool _hasTrack = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _SongTintedBackground old) {
    super.didUpdateWidget(old);
    if (old.queue != widget.queue) _refresh();
  }

  Future<void> _refresh() async {
    final track = widget.queue.current;
    final hasTrack = track != null;
    String? cover;
    if (hasTrack) {
      try {
        cover = sl<LikeCubit>().resolveCoverFor(track) ?? track.coverUrl;
      } catch (_) {
        cover = track.coverUrl;
      }
    }
    final bg = hasTrack
        ? (await _dominantFor(cover)) ?? widget.defaultBg
        : widget.defaultBg;
    if (!mounted) return;
    setState(() {
      _bg = bg;
      _cover = cover;
      _hasTrack = hasTrack;
    });
  }

  Future<Color?> _dominantFor(String? cover) async {
    if (cover == null || cover.isEmpty) return null;
    final palette = await paletteForCover(cover);
    if (palette == null) return null;
    // Dark theme keeps the surface dark-ish; light theme uses the cover's
    // dominant hue directly. Blend toward the default so it never shouts.
    final mix = widget.isDark ? 0.30 : 0.45;
    return Color.lerp(widget.defaultBg, palette.dominant, mix);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        color: _bg,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_hasTrack && _cover != null && _cover!.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Transform.scale(
                  scale: 1.3,
                  child: imageFromUrl(
                    _cover!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          // Veil keeps content readable over the artwork.
          Positioned.fill(
            child: ColoredBox(
              color: _bg.withValues(alpha: widget.isDark ? 0.72 : 0.55),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Opens the new tabbed settings sheet.
void showSettingsSheet(BuildContext context, {
  required String username,
  required bool isDark,
  required ValueChanged<bool> onThemeChanged,
  required VoidCallback onLanguageChanged,
  String likedCount = '0',
  String downloadedCount = '0',
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => BlocProvider<QueueCubit>.value(
      value: sl<QueueCubit>(),
      child: SettingsSheet(
        username: username, isDark: isDark,
        onThemeChanged: onThemeChanged,
        onLanguageChanged: onLanguageChanged,
        likedCount: likedCount, downloadedCount: downloadedCount,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────
//  Root widget
// ─────────────────────────────────────────────────────
class SettingsSheet extends StatefulWidget {
  final String username;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLanguageChanged;
  final String likedCount;
  final String downloadedCount;

  const SettingsSheet({
    super.key,
    required this.username,
    required this.isDark,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    this.likedCount = '0',
    this.downloadedCount = '0',
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedTab; // null = profile/stats view, 0..3 = specific tab

  /// Real account tier read from the local premium DB (free/premium/lifetime),
  /// so the header + advanced settings never claim "Premium" for free users.
  PremiumStatus? _premium;

  Future<void> _loadPremium() async {
    try {
      final status = await sl<PremiumCache>().getPremiumStatus();
      if (mounted) setState(() => _premium = status);
    } catch (_) {}
  }

  // Tab order: Apariencia first (live color), then Descargas, Rendimiento, Más.
  static final List<({IconData icon, String label})> _bubbleTabs = [
    (icon: Icons.palette_outlined, label: 'Apariencia'),
    (icon: Icons.download_rounded, label: 'Descargas'),
    (icon: Icons.speed_rounded, label: 'Rendimiento'),
    (icon: Icons.more_horiz, label: 'Más'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _bubbleTabs.length, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _loadPremium();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// One circular icon bubble: a small glowing circle with the icon, and a
  /// tiny label underneath. Active bubble gets a filled glow + ring.
  Widget _bubble(int i, Color glowColor, Color onBg, Responsive r) {
    final active = _tabController.index == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          if (_selectedTab == i) {
            _selectedTab = null; // tap again → back to profile
          } else {
            _selectedTab = i;
            _tabController.animateTo(i);
          }
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active
                  ? LinearGradient(
                      colors: [
                        glowColor.withValues(alpha: 0.95),
                        glowColor.withValues(alpha: 0.55),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: active ? null : onBg.withValues(alpha: 0.06),
              border: Border.all(
                color: active
                    ? Colors.white.withValues(alpha: 0.35)
                    : onBg.withValues(alpha: 0.1),
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              _bubbleTabs[i].icon,
              size: r.footerSize + 2,
              color: active ? Colors.white : onBg.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 4),
          Text(
            _bubbleTabs[i].label,
            style: TextStyle(
              fontSize: r.footerSize - 3,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? glowColor : onBg.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    // LIVE theme: read from Theme.of instead of the frozen widget.isDark so
    // toggling dark/light inside the modal updates the sheet instantly.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final bg = AppColors.surface(isDark);

    return BlocBuilder<QueueCubit, QueueState>(
      builder: (context, queue) {
        final hasTrack = queue.hasCurrent;
        return _SongTintedBackground(
          key: ValueKey('settings-bg'),
          queue: queue,
          isDark: isDark,
          defaultBg: bg,
          child: _buildSheet(r, isDark, onBg, glowColor, bg, hasTrack),
        );
      },
    );
  }

  Widget _buildSheet(
    Responsive r,
    bool isDark,
    Color onBg,
    Color glowColor,
    Color bg,
    bool hasTrack,
  ) {
    Widget sheet = Container(
      // A bit bigger than half: leaves the top ~30% visible behind the
      // modal so the page context stays, but tabs have room to breathe.
      height: MediaQuery.of(context).size.height * 0.7,
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        // Transparent when a track is playing: the _SongTintedBackground
        // provides the blurred cover + veil underneath.
        color: hasTrack ? Colors.transparent : bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            SizedBox(height: r.spacingM),
            // Drag handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.spacingM),
            // Compact profile header (always visible)
            _ProfileHeader(
              username: widget.username,
              glowColor: glowColor,
              likedCount: widget.likedCount,
              downloadedCount: widget.downloadedCount,
              premium: _premium,
            ),
            SizedBox(height: r.spacingM),
            // Bubble tabs — Apariencia first. Four small circular bubbles
            // with a tiny label under each; the active one glows. No scroll,
            // no boxes.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < _bubbleTabs.length; i++)
                    _bubble(i, glowColor, onBg, r),
                ],
              ),
            ),
            SizedBox(height: r.spacingS),
            // Content: profile/stats when no tab selected, tab content otherwise.
            Expanded(
              child: _selectedTab == null
                  ? _ProfileStatsView(
                      glowColor: glowColor,
                      likedCount: widget.likedCount,
                      downloadedCount: widget.downloadedCount,
                      premium: _premium,
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _AppearanceTab(
                          isDark: isDark, glowColor: glowColor,
                          onThemeChanged: widget.onThemeChanged,
                          onLanguageChanged: widget.onLanguageChanged,
                        ),
                        _DownloadsTab(glowColor: glowColor),
                        _PerformanceTab(glowColor: glowColor),
                        _MoreTab(
                          glowColor: glowColor,
                          premium: _premium,
                          onPremiumChanged: _loadPremium,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );

    if (hasTrack) {
      sheet = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: sheet,
        ),
      );
    }
    return sheet;
  }
}

// ═══════════════════════════════════════════════════════
//  Compact profile header
// ═══════════════════════════════════════════════════════
class _ProfileHeader extends StatelessWidget {
  final String username;
  final Color glowColor;
  final String likedCount;
  final String downloadedCount;
  final PremiumStatus? premium;

  const _ProfileHeader({
    required this.username,
    required this.glowColor,
    required this.likedCount,
    required this.downloadedCount,
    this.premium,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [glowColor, glowColor.withValues(alpha: 0.5)],
              ),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.25), blurRadius: 12)],
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          SizedBox(width: r.spacingS),
          // Name + premium
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username.isNotEmpty ? username : 'Guest',
                  style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.bold, color: onBg),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                Row(children: [
                  Icon(
                    (premium?.isPremium ?? false)
                        ? Icons.workspace_premium_rounded
                        : Icons.person_outline_rounded,
                    size: r.footerSize - 1,
                    color: (premium?.isPremium ?? false)
                        ? glowColor
                        : onBg.withValues(alpha: 0.5),
                  ),
                  SizedBox(width: 3),
                  Text(
                    (premium?.isPremium ?? false)
                        ? AppLocalizations.of(context).setup.premium
                        : 'Free',
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: (premium?.isPremium ?? false)
                          ? glowColor
                          : onBg.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          // Mini stats
          _miniStat(context, Icons.favorite, Colors.redAccent, likedCount),
          SizedBox(width: r.spacingM),
          _miniStat(context, Icons.download_done, const Color(0xFF4CAF50), downloadedCount),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, IconData icon, Color color, String value) {
    final r = Responsive(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: r.footerSize, color: color),
        SizedBox(width: 3),
        Text(value, style: TextStyle(fontSize: r.subtitleSize - 1, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Profile / Stats view (shown when no tab is selected)
// ═══════════════════════════════════════════════════════

class _ProfileStatsView extends StatefulWidget {
  final Color glowColor;
  final String likedCount;
  final String downloadedCount;
  final PremiumStatus? premium;
  const _ProfileStatsView({
    required this.glowColor,
    required this.likedCount,
    required this.downloadedCount,
    this.premium,
  });
  @override
  State<_ProfileStatsView> createState() => _ProfileStatsViewState();
}

class _ProfileStatsViewState extends State<_ProfileStatsView> {
  Map<String, dynamic> _stats = {};
  List<dynamic> _topTracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Stats come from the LOCAL Drift tables — the Go in-memory tracker is
    // empty on device so the old RPCs always showed zeros.
    try {
      final stats = await sl<PlaybackCache>().getProfileStats();
      if (mounted) _stats = stats;
    } catch (_) {}
    try {
      final top = await sl<PlaybackCache>().getTopTracksWithNames(5);
      if (mounted) _topTracks = top;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final loc = AppLocalizations.of(context);
    final glow = widget.glowColor;

    if (_loading) {
      return Center(child: CircularProgressIndicator(strokeWidth: 2, color: glow));
    }

    final totalPlays = _stats['totalPlays'] ?? 0;
    final uniqueTracks = _stats['uniqueTracks'] ?? 0;
    final uniqueArtists = _stats['uniqueArtists'] ?? 0;
    final totalDurationMs = _stats['totalDuration'] ?? 0;
    final hours = (totalDurationMs / 3600000).floor();
    final mins = ((totalDurationMs % 3600000) / 60000).floor();
    final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tier banner: tells free users about the 8h download window ──
          if (widget.premium?.isPremium ?? false)
            Container(
              margin: EdgeInsets.only(bottom: r.spacingM),
              padding: EdgeInsets.all(r.spacingM),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [glow.withValues(alpha: 0.20), glow.withValues(alpha: 0.07)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: glow.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Icon(Icons.workspace_premium_rounded, color: glow, size: r.subtitleSize),
                SizedBox(width: r.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.setup.premium,
                          style: TextStyle(fontSize: r.subtitleSize - 1, fontWeight: FontWeight.w700, color: glow)),
                      SizedBox(height: 2),
                      Text(
                        loc.setup.premiumInfo,
                        style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ]),
            )
          else
            Container(
              margin: EdgeInsets.only(bottom: r.spacingM),
              padding: EdgeInsets.all(r.spacingM),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [glow.withValues(alpha: 0.16), glow.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: glow.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.timer_rounded, color: glow, size: r.subtitleSize),
                SizedBox(width: r.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Free',
                          style: TextStyle(fontSize: r.subtitleSize - 1, fontWeight: FontWeight.w700, color: glow)),
                      SizedBox(height: 2),
                      Text(
                        loc.setup.freeInfo,
                        style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          _sectionHeader(Icons.bar_chart_rounded, loc.setup.totalPlays, onBg, r),
          SizedBox(height: r.spacingS),
          _statsGrid([
            _statCard(Icons.play_circle_outline, loc.setup.totalPlays, '$totalPlays', glow, onBg, r),
            _statCard(Icons.music_note_rounded, loc.setup.uniqueTracks, '$uniqueTracks', glow, onBg, r),
            _statCard(Icons.people_outline, loc.setup.uniqueArtists, '$uniqueArtists', glow, onBg, r),
            _statCard(Icons.schedule_rounded, loc.setup.listeningTime, durationStr, glow, onBg, r),
          ], r),
          SizedBox(height: r.spacingM),
          _sectionHeader(Icons.library_music_rounded, loc.setup.likedSongs, onBg, r),
          SizedBox(height: r.spacingS),
          _statsGrid([
            _statCard(Icons.favorite_rounded, loc.setup.likedSongs, widget.likedCount, glow, onBg, r),
            _statCard(Icons.download_done_rounded, loc.setup.downloadedSongs, widget.downloadedCount, glow, onBg, r),
          ], r),
          if (_topTracks.isNotEmpty) ...[
            SizedBox(height: r.spacingM),
            _sectionHeader(Icons.leaderboard_rounded, loc.setup.mostPlayed, onBg, r),
            SizedBox(height: r.spacingS),
            ..._topTracks.map((t) {
              final name = t is Map ? (t['name'] ?? '') : '';
              final artist = t is Map ? (t['artist'] ?? '') : '';
              final id = t is Map ? (t['trackId'] ?? '') : '';
              final count = t is Map ? (t['count'] ?? 0) : 0;
              return Container(
                margin: EdgeInsets.only(bottom: r.spacingXS),
                padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.music_note_rounded, size: r.footerSize, color: glow.withValues(alpha: 0.6)),
                  SizedBox(width: r.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : id,
                          style: TextStyle(fontSize: r.subtitleSize - 1, color: onBg),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (artist.isNotEmpty)
                          Text(
                            artist,
                            style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.4)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: glow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('$count', style: TextStyle(fontSize: r.footerSize - 2, color: glow, fontWeight: FontWeight.w700)),
                  ),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label, Color onBg, Responsive r) {
    return Row(children: [
      Icon(icon, size: r.subtitleSize, color: widget.glowColor),
      SizedBox(width: r.spacingS),
      Text(label, style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: onBg)),
    ]);
  }

  Widget _statsGrid(List<Widget> children, Responsive r) {
    return Wrap(
      spacing: r.spacingS,
      runSpacing: r.spacingS,
      children: children.map((c) => SizedBox(
        width: (MediaQuery.of(context).size.width - r.spacingL * 2 - r.spacingS) / 2,
        child: c,
      )).toList(),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color glow, Color onBg, Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.spacingM),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: glow.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: r.footerSize + 2, color: glow),
        SizedBox(height: r.spacingXS),
        Text(value, style: TextStyle(fontSize: r.titleSize, fontWeight: FontWeight.w800, color: onBg)),
        SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.5))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 1: Apariencia — LIVE theme/color
// ═══════════════════════════════════════════════════════
class _AppearanceTab extends StatelessWidget {
  final bool isDark;
  final Color glowColor;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLanguageChanged;

  const _AppearanceTab({
    required this.isDark,
    required this.glowColor,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = AppColors.onSurface(isDark);
    final loc = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Theme — LIVE segmented picker ──
          GlassContainer(
            borderRadius: 16, borderColor: onBg.withValues(alpha: 0.08),
            bgColor: onBg.withValues(alpha: 0.03),
            padding: EdgeInsets.all(r.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: glowColor, size: r.subtitleSize),
                  SizedBox(width: r.spacingS),
                  Text(loc.setup.theme,
                      style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: onBg)),
                ]),
                SizedBox(height: r.spacingS),
                // Two big pretty option tiles: Oscuro / Claro.
                Row(children: [
                  Expanded(
                    child: _themeTile(
                      icon: Icons.dark_mode_rounded,
                      label: loc.setup.darkMode,
                      selected: isDark,
                      glowColor: glowColor, onBg: onBg, r: r,
                      onTap: () { if (!isDark) onThemeChanged(true); },
                    ),
                  ),
                  SizedBox(width: r.spacingS),
                  Expanded(
                    child: _themeTile(
                      icon: Icons.light_mode_rounded,
                      label: loc.setup.lightMode,
                      selected: !isDark,
                      glowColor: glowColor, onBg: onBg, r: r,
                      onTap: () { if (isDark) onThemeChanged(false); },
                    ),
                  ),
                ]),
                SizedBox(height: r.spacingXS),
                Text(
                  'El cambio se aplica al instante en todas las vistas.',
                  style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
          SizedBox(height: r.spacingS),
          // ── Language ──
          SettingsLanguageSection(
            onBg: onBg, glowColor: glowColor, loc: loc,
            onTap: onLanguageChanged,
            currentLanguage: loc.locale.languageCode == 'es' ? 'Español' : 'English',
          ),
        ],
      ),
    );
  }

  /// One big tappable theme tile (Oscuro / Claro) with icon + label.
  Widget _themeTile({
    required IconData icon,
    required String label,
    required bool selected,
    required Color glowColor,
    required Color onBg,
    required Responsive r,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(vertical: r.spacingM, horizontal: r.spacingS),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [glowColor.withValues(alpha: 0.28), glowColor.withValues(alpha: 0.10)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : onBg.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? glowColor.withValues(alpha: 0.6) : onBg.withValues(alpha: 0.1),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon, size: r.subtitleSize + 8,
              color: selected ? glowColor : onBg.withValues(alpha: 0.5)),
          SizedBox(height: r.spacingXS),
          Text(label,
              style: TextStyle(
                fontSize: r.subtitleSize - 2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? glowColor : onBg.withValues(alpha: 0.6),
              )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 2: Descargas — quality + lyrics + video (no priority)
// ═══════════════════════════════════════════════════════
class _DownloadsTab extends StatelessWidget {
  final Color glowColor;
  const _DownloadsTab({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = AppColors.onSurface(Theme.of(context).brightness == Brightness.dark);
    final loc = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: r.spacingS),
          SettingsStorageSection(onBg: onBg, glowColor: glowColor, loc: loc),
          SizedBox(height: r.spacingS),
          _DownloadQualityCard(glowColor: glowColor),
          // No download priority section — the app handles provider
          // ordering internally.
        ],
      ),
    );
  }
}

/// Audio quality + lyrics + video settings in clean dropdown rows.
class _DownloadQualityCard extends StatefulWidget {
  final Color glowColor;
  const _DownloadQualityCard({required this.glowColor});

  @override
  State<_DownloadQualityCard> createState() => _DownloadQualityCardState();
}

class _DownloadQualityCardState extends State<_DownloadQualityCard> {
  DownloadSettings _settings = const DownloadSettings();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await sl<SettingsCache>().getDownloadSettings();
    if (mounted) setState(() { _settings = s; _loaded = true; });
  }

  Future<void> _update(DownloadSettings s) async {
    setState(() => _settings = s);
    await sl<SettingsCache>().saveDownloadSettings(s);
    try {
      sl<PlayerCubit>().applyDownloadSettings(
        audioQuality: s.audioQuality,
        videoQuality: s.videoQuality,
        videoEnabled: s.videoEnabled,
        lyricsEnabled: s.lyricsEnabled,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final loc = AppLocalizations.of(context);
    if (!_loaded) return SizedBox.shrink();

    return GlassContainer(
      borderRadius: 16, borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(Icons.music_note_rounded, loc.setup.audioQuality, onBg, r),
          SizedBox(height: r.spacingXS),
          _dropdownRow(
            icon: Icons.audiotrack_rounded,
            hint: _qualityLabel(_settings.audioQuality, loc),
            options: const ['flac', 'hifi', 'high', 'medium', 'low'],
            labelFor: (q) => _qualityLabel(q, loc),
            current: _settings.audioQuality,
            onChanged: (v) => _update(_settings.copyWith(audioQuality: v)),
            glowColor: widget.glowColor, onBg: onBg,
          ),
          SizedBox(height: r.spacingM),
          // ── Video toggle + quality dropdown ──
          _switchRow(
            icon: Icons.videocam_rounded,
            label: loc.setup.videoDownload,
            value: _settings.videoEnabled,
            onChanged: (v) => _update(_settings.copyWith(videoEnabled: v)),
            glowColor: widget.glowColor, onBg: onBg,
          ),
          if (_settings.videoEnabled) ...[
            SizedBox(height: r.spacingXS),
            _dropdownRow(
              icon: Icons.high_quality_rounded,
              hint: _videoLabel(_settings.videoQuality),
              options: const ['720p', '1080p', '480p'],
              labelFor: _videoLabel,
              current: _settings.videoQuality,
              onChanged: (v) => _update(_settings.copyWith(videoQuality: v)),
              glowColor: widget.glowColor, onBg: onBg,
            ),
          ],
          SizedBox(height: r.spacingM),
          // ── Lyrics toggle + source dropdown ──
          _switchRow(
            icon: Icons.lyrics_rounded,
            label: loc.setup.lyricsDownload,
            value: _settings.lyricsEnabled,
            onChanged: (v) => _update(_settings.copyWith(lyricsEnabled: v)),
            glowColor: widget.glowColor, onBg: onBg,
          ),
          if (_settings.lyricsEnabled) ...[
            SizedBox(height: r.spacingXS),
            _dropdownRow(
              icon: Icons.format_quote_rounded,
              hint: _lyricsLabel(_settings.lyricsSource),
              options: const ['lrclib', 'genius', 'musixmatch'],
              labelFor: _lyricsLabel,
              current: _settings.lyricsSource,
              onChanged: (v) => _update(_settings.copyWith(lyricsSource: v)),
              glowColor: widget.glowColor, onBg: onBg,
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerRow(IconData icon, String label, Color onBg, Responsive r) {
    return Row(children: [
      Icon(icon, size: r.subtitleSize, color: widget.glowColor),
      SizedBox(width: r.spacingS),
      Text(label,
          style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: onBg)),
    ]);
  }

  Widget _switchRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color glowColor,
    required Color onBg,
  }) {
    final r = Responsive(context);
    return Row(children: [
      Icon(icon, color: onBg.withValues(alpha: 0.55), size: r.footerSize + 2),
      SizedBox(width: r.spacingS),
      Expanded(child: Text(label,
          style: TextStyle(fontSize: r.subtitleSize - 1, color: onBg, fontWeight: FontWeight.w500))),
      Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: glowColor.withValues(alpha: 0.3),
        activeThumbColor: glowColor,
      ),
    ]);
  }

  /// A clean labeled dropdown: icon + hint text + arrow, opening a themed
  /// bottom-sheet picker so every option is readable and the chosen one
  /// glows.
  Widget _dropdownRow({
    required IconData icon,
    required String hint,
    required List<String> options,
    required String Function(String) labelFor,
    required String current,
    required ValueChanged<String> onChanged,
    required Color glowColor,
    required Color onBg,
  }) {
    final r = Responsive(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPicker(
        context: context,
        title: hint,
        options: options,
        labelFor: labelFor,
        current: current,
        onChanged: onChanged,
        glowColor: glowColor, onBg: onBg, r: r,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: glowColor.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, size: r.footerSize + 2, color: glowColor),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Text(hint,
                style: TextStyle(fontSize: r.subtitleSize - 1, color: onBg, fontWeight: FontWeight.w600)),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: onBg.withValues(alpha: 0.4), size: r.footerSize + 4),
        ]),
      ),
    );
  }

  /// Bottom-sheet option picker: each row is a big tappable surface with a
  /// check on the selected one — much easier to read than pills.
  Future<void> _showPicker({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String Function(String) labelFor,
    required String current,
    required ValueChanged<String> onChanged,
    required Color glowColor,
    required Color onBg,
    required Responsive r,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final sheetOnBg = AppColors.onSurface(isDark);
        final sheetBg = AppColors.surface(isDark);
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(sheetCtx).bottom + r.spacingM),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: r.spacingM),
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: sheetOnBg.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2))),
                SizedBox(height: r.spacingM),
                Text(title,
                    style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: sheetOnBg)),
                SizedBox(height: r.spacingS),
                ...options.map((q) {
                  final sel = q == current;
                  return InkWell(
                    onTap: () => Navigator.pop(sheetCtx, q),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: r.spacingL, vertical: r.spacingM),
                      child: Row(children: [
                        Expanded(
                          child: Text(labelFor(q),
                              style: TextStyle(
                                fontSize: r.subtitleSize,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel ? glowColor : sheetOnBg.withValues(alpha: 0.7),
                              )),
                        ),
                        if (sel)
                          Icon(Icons.check_circle_rounded, color: glowColor, size: r.footerSize + 4),
                      ]),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && selected != current) onChanged(selected);
  }

  String _qualityLabel(String q, AppLocalizations loc) {
    switch (q) {
      case 'flac': return loc.setup.flac;
      case 'hifi': return loc.setup.hifi;
      case 'high': return loc.setup.high;
      case 'medium': return loc.setup.medium;
      case 'low': return loc.setup.low;
      default: return q;
    }
  }

  String _videoLabel(String q) {
    switch (q) {
      case '1080p': return 'Full HD (1080p)';
      case '720p': return 'HD (720p)';
      case '480p': return 'SD (480p)';
      default: return q;
    }
  }

  String _lyricsLabel(String q) {
    switch (q) {
      case 'lrclib': return 'LRCLib';
      case 'genius': return 'Genius';
      case 'musixmatch': return 'Musixmatch';
      default: return q;
    }
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 3: Rendimiento — explanatory, pretty
// ═══════════════════════════════════════════════════════
class _PerformanceTab extends StatelessWidget {
  final Color glowColor;
  const _PerformanceTab({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = AppColors.onSurface(Theme.of(context).brightness == Brightness.dark);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: r.spacingS),
          // Header row (no nested box — the section below is the card).
          Row(children: [
            Icon(Icons.speed_rounded, color: glowColor, size: r.subtitleSize),
            SizedBox(width: r.spacingS),
            Text('Rendimiento', style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: onBg)),
          ]),
          SizedBox(height: 4),
          Text(
            'Equilibra calidad de audio y consumo de datos según tu dispositivo y conexión.',
            style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.5), height: 1.3),
          ),
          SizedBox(height: r.spacingM),
          SettingsPerformanceSection(onBg: onBg, glowColor: glowColor),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 4: Más — cache + version info
// ═══════════════════════════════════════════════════════
class _MoreTab extends StatefulWidget {
  final Color glowColor;
  final PremiumStatus? premium;
  final Future<void> Function() onPremiumChanged;
  const _MoreTab({
    required this.glowColor,
    this.premium,
    required this.onPremiumChanged,
  });
  @override
  State<_MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<_MoreTab> {

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: r.spacingS),
          // ── Premium status + activation ──
          _premiumCard(context, onBg, r),
          SizedBox(height: r.spacingM),
          // ── Report a bug / suggestion ──
          _reportCard(context, onBg, r),
          SizedBox(height: r.spacingM),
          // ── Streaming cache — explained ──
          _cacheExplained(context, onBg, r),
          SizedBox(height: r.spacingM),
          _versionInfoCard(context, r, onBg, widget.glowColor),
        ],
      ),
    );
  }

  /// Report a bug / suggestion: opens a small form and submits it to the
  /// developer's GitHub issues via the API, so reports land in the repo.
  Widget _reportCard(BuildContext context, Color onBg, Responsive r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.bug_report_rounded, color: widget.glowColor, size: r.subtitleSize),
        SizedBox(width: r.spacingS),
        Text(AppLocalizations.of(context).setup.reportBug,
            style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: onBg)),
      ]),
      SizedBox(height: 4),
      Text(
        AppLocalizations.of(context).setup.reportDesc,
        style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.5), height: 1.3),
      ),
      SizedBox(height: r.spacingS),
      GestureDetector(
        onTap: _showReportDialog,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingM),
          decoration: BoxDecoration(
            color: onBg.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.glowColor.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.edit_rounded, size: r.subtitleSize + 2, color: widget.glowColor),
            SizedBox(width: r.spacingS),
            Text(AppLocalizations.of(context).setup.reportBug,
                style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg.withValues(alpha: 0.8))),
          ]),
        ),
      ),
    ]);
  }

  /// Opens the report form dialog. On send, creates a GitHub issue in the
  /// app's repo so the developer receives it directly.
  Future<void> _showReportDialog() async {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final bg = AppColors.surface(isDark);
    final glow = widget.glowColor;

    var isBug = true;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    var sending = false;
    var sent = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Icon(isBug ? Icons.bug_report_rounded : Icons.lightbulb_rounded,
                    color: isBug ? Colors.redAccent : Colors.amber, size: 22),
                SizedBox(width: r.spacingS),
                Text(loc.setup.reportBug,
                    style: TextStyle(color: onBg, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type toggle: Bug / Sugerencia
                    Row(children: [
                      Expanded(
                        child: _reportTypeChip(
                          label: loc.setup.reportTypeBug,
                          selected: isBug,
                          color: Colors.redAccent,
                          onBg: onBg, glow: glow,
                          onTap: () => setModalState(() => isBug = true),
                        ),
                      ),
                      SizedBox(width: r.spacingS),
                      Expanded(
                        child: _reportTypeChip(
                          label: loc.setup.reportTypeSuggestion,
                          selected: !isBug,
                          color: Colors.amber,
                          onBg: onBg, glow: glow,
                          onTap: () => setModalState(() => isBug = false),
                        ),
                      ),
                    ]),
                    SizedBox(height: r.spacingM),
                    TextField(
                      controller: titleCtrl,
                      style: TextStyle(color: onBg),
                      decoration: InputDecoration(
                        labelText: loc.setup.reportTitle,
                        labelStyle: TextStyle(color: onBg.withValues(alpha: 0.5)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: onBg.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: glow),
                        ),
                      ),
                    ),
                    SizedBox(height: r.spacingS),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 4,
                      style: TextStyle(color: onBg),
                      decoration: InputDecoration(
                        hintText: loc.setup.reportBody,
                        hintStyle: TextStyle(color: onBg.withValues(alpha: 0.4)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: onBg.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: glow),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.pop(ctx),
                  child: Text(loc.setup.cancel, style: TextStyle(color: onBg.withValues(alpha: 0.6))),
                ),
                FilledButton(
                  onPressed: sending
                      ? null
                      : () async {
                          setModalState(() => sending = true);
                          final ok = await _submitReport(
                            isBug: isBug,
                            title: titleCtrl.text.trim(),
                            body: bodyCtrl.text.trim(),
                          );
                          sent = ok;
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: isBug ? Colors.redAccent : glow,
                  ),
                  child: sending
                      ? SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(loc.setup.reportSend, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent ? loc.setup.reportSent : loc.setup.reportFailed),
          backgroundColor: sent ? Colors.green.shade700 : Colors.red.shade700,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _reportTypeChip({
    required String label,
    required bool selected,
    required Color color,
    required Color onBg,
    required Color glow,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : onBg.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.6) : onBg.withValues(alpha: 0.12),
            width: 1.4,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? color : onBg.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  /// Creates a GitHub issue in QuopTron/bitly using the configured token.
  /// Returns true when the issue was created successfully.
  Future<bool> _submitReport({
    required bool isBug,
    required String title,
    required String body,
  }) async {
    if (title.isEmpty) return false;
    try {
      final pkg = await PackageInfo.fromPlatform();
      final appVersion = 'v${pkg.version}';
      final prefix = isBug ? '[Bug]' : '[Sugerencia]';
      final issueBody = [
        body,
        '',
        '---',
        'App: Bitly $appVersion',
        'Plataforma: ${Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : Platform.isLinux ? 'Linux' : Platform.isWindows ? 'Windows' : Platform.isMacOS ? 'macOS' : 'desktop'}',
      ].join('\n');
      final resp = await http.post(
        Uri.parse('https://api.github.com/repos/QuopTron/bitly/issues'),
        headers: {
          'Authorization': 'token $githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': '$prefix $title',
          'body': issueBody,
        }),
      );
      return resp.statusCode == 201 || resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Premium card: shows the real tier (Free/Premium) and lets free users
  /// activate a premium code right from settings.
  Widget _premiumCard(BuildContext context, Color onBg, Responsive r) {
    final isPremium = widget.premium?.isPremium ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(
          isPremium ? Icons.workspace_premium_rounded : Icons.person_outline_rounded,
          color: widget.glowColor,
          size: r.subtitleSize,
        ),
        SizedBox(width: r.spacingS),
        Text('Cuenta', style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: onBg)),
      ]),
      SizedBox(height: 4),
      Text(
        isPremium
            ? 'Tienes Premium: descargas ilimitadas para siempre.'
            : 'Modo Free: acceso a descargas gratis por 8 horas desde tu primera activación.',
        style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.5), height: 1.3),
      ),
      SizedBox(height: r.spacingS),
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(r.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPremium
                ? [widget.glowColor.withValues(alpha: 0.16), widget.glowColor.withValues(alpha: 0.05)]
                : [widget.glowColor.withValues(alpha: 0.10), onBg.withValues(alpha: 0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.glowColor.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(
            isPremium ? Icons.check_circle_rounded : Icons.workspace_premium_rounded,
            color: widget.glowColor,
            size: r.footerSize + 4,
          ),
          SizedBox(width: r.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'Premium activo' : 'Free',
                  style: TextStyle(
                    fontSize: r.subtitleSize - 1,
                    fontWeight: FontWeight.w600,
                    color: isPremium ? widget.glowColor : onBg,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  isPremium
                      ? 'Cuenta con todos los beneficios'
                      : 'Activa un código para descargas ilimitadas',
                  style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
          if (!isPremium)
            TextButton(
              onPressed: _activatePremium,
              child: Text('Activar', style: TextStyle(color: widget.glowColor, fontWeight: FontWeight.w700, fontSize: r.footerSize)),
            ),
        ]),
      ),
    ]);
  }

  /// Asks for a premium code and validates it against the GitHub registry,
  /// then persists the tier locally so the whole app sees it.
  Future<void> _activatePremium() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final onBg = AppColors.onSurface(isDark);
        return AlertDialog(
          backgroundColor: AppColors.surface(isDark),
          title: Text('Activar código premium',
              style: TextStyle(color: onBg, fontSize: 18, fontWeight: FontWeight.w700)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: onBg),
            decoration: InputDecoration(
              hintText: 'Código premium',
              hintStyle: TextStyle(color: onBg.withValues(alpha: 0.4)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: onBg.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.glowColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: onBg.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text('Activar', style: TextStyle(color: widget.glowColor, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (code == null || code.isEmpty) return;
    final error = await PremiumService().validatePremiumCode(code);
    if (!mounted) return;
    if (error == null) {
      await sl<PremiumCache>().activatePremium(code);
      await widget.onPremiumChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Premium activado ✓'), backgroundColor: Colors.green.shade700),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Widget _cacheExplained(BuildContext context, Color onBg, Responsive r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.cached_rounded, color: widget.glowColor, size: r.subtitleSize),
        SizedBox(width: r.spacingS),
        Text('Caché de streaming', style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: onBg)),
      ]),
      SizedBox(height: 4),
      Text(
        'Guarda temporalmente las canciones que reproduces para que las que repites suenen al instante y sin gastar datos.',
        style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.5), height: 1.3),
      ),
      SizedBox(height: r.spacingS),
      SettingsCacheSection(onBg: onBg, glowColor: widget.glowColor),
    ]);
  }

  /// Version info card: shows the current version and taps open a mini-modal
  /// listing all available releases (old + new).
  Widget _versionInfoCard(BuildContext context, Responsive r, Color onBg, Color glow) {
    return GestureDetector(
      onTap: () => _showVersionSheet(context, glow, onBg, r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingM),
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: onBg.withValues(alpha: 0.1)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.info_outline_rounded, size: r.subtitleSize + 2, color: glow),
          SizedBox(width: r.spacingS),
          Text('Versiones', style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg.withValues(alpha: 0.7))),
          SizedBox(width: r.spacingXS),
          Icon(Icons.chevron_right_rounded, size: r.subtitleSize, color: onBg.withValues(alpha: 0.3)),
        ]),
      ),
    );
  }

  /// Opens a bottom sheet that fetches current version + all GitHub releases
  /// and shows them as a clean list with the latest highlighted.
  Future<void> _showVersionSheet(BuildContext context, Color glow, Color onBg, Responsive r) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VersionSheet(glowColor: glow),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Version info mini-modal
// ═══════════════════════════════════════════════════════

class _VersionSheet extends StatefulWidget {
  final Color glowColor;
  const _VersionSheet({required this.glowColor});

  @override
  State<_VersionSheet> createState() => _VersionSheetState();
}

class _VersionSheetState extends State<_VersionSheet> {
  String _currentVersion = '';
  String _latestVersion = '';
  List<_ReleaseInfo> _releases = [];
  bool _loading = true;
  UpdateInfo? _updateInfo;

  static const _releasesUrl =
      'https://api.github.com/repos/QuopTron/bitly/releases';
  static const _latestUrl =
      'https://api.github.com/repos/QuopTron/bitly/releases/latest';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      _currentVersion = pkg.version;
    } catch (_) {}

    try {
      // Fetch latest for update info
      final latestResp = await http.get(
        Uri.parse(_latestUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (latestResp.statusCode == 200) {
        final json = jsonDecode(latestResp.body);
        final tag = json['tag_name'] as String? ?? '';
        _latestVersion = tag.replaceFirst('v', '').trim();
      }
    } catch (_) {}

    try {
      // Fetch all releases for the version list
      final resp = await http.get(
        Uri.parse(_releasesUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        _releases = list
            .where((r) => (r['tag_name'] as String? ?? '').isNotEmpty)
            .map((r) {
              final assets = (r['assets'] as List<dynamic>?) ?? [];
              String apkUrl = '';
              // Try to find a matching APK, then fall back to any .apk
              for (final a in assets) {
                final name = (a['name'] as String? ?? '');
                if (name.endsWith('.apk')) { apkUrl = (a['browser_download_url'] as String?) ?? ''; break; }
              }
              return _ReleaseInfo(
                tag: (r['tag_name'] as String? ?? ''),
                body: (r['body'] as String? ?? ''),
                date: (r['published_at'] as String? ?? '').substring(0, 10),
                downloadUrl: apkUrl,
              );
            })
            .toList();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);

    // Fetch update info in background for the download button
    try {
      final info = await UpdateService().checkForUpdate();
      if (mounted) setState(() => _updateInfo = info);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final bg = AppColors.surface(isDark);
    final glow = widget.glowColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            SizedBox(height: r.spacingM),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: onBg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            SizedBox(height: r.spacingM),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingM),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: glow, size: r.subtitleSize + 2),
                SizedBox(width: r.spacingS),
                Text('Versiones', style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: onBg)),
              ]),
            ),
            SizedBox(height: r.spacingS),
            // Current + latest version row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingM),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(r.spacingM),
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: glow.withValues(alpha: 0.2)),
                ),
                child: _loading
                    ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: glow))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.phone_android_rounded, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.6)),
                            SizedBox(width: r.spacingS),
                            Text('Instalada', style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5))),
                            Spacer(),
                            Text('v$_currentVersion', style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: onBg)),
                          ]),
                          if (_latestVersion.isNotEmpty) ...[
                            SizedBox(height: r.spacingS),
                            Divider(height: 1, color: onBg.withValues(alpha: 0.08)),
                            SizedBox(height: r.spacingS),
                            Row(children: [
                              Icon(Icons.cloud_download_rounded, size: r.footerSize + 2, color: glow.withValues(alpha: 0.8)),
                              SizedBox(width: r.spacingS),
                              Text('Última', style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5))),
                              Spacer(),
                              Text('v$_latestVersion', style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: glow)),
                            ]),
                          ],
                        ],
                      ),
              ),
            ),
            SizedBox(height: r.spacingM),
            // Release list
            if (_loading)
              Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: glow.withValues(alpha: 0.5))))
            else if (_releases.isEmpty)
              Expanded(child: Center(child: Text('No se encontraron versiones', style: TextStyle(color: onBg.withValues(alpha: 0.4), fontSize: r.footerSize))))
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: r.spacingM),
                  itemCount: _releases.length,
                  itemBuilder: (ctx, i) {
                    final rel = _releases[i];
                    final tagClean = rel.tag.replaceFirst('v', '').trim();
                    final isCurrent = tagClean == _currentVersion;
                    final isLatest = tagClean == _latestVersion;

                    return Container(
                      margin: EdgeInsets.only(bottom: r.spacingS),
                      padding: EdgeInsets.all(r.spacingM),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? glow.withValues(alpha: 0.12)
                            : onBg.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? glow.withValues(alpha: 0.4)
                              : isLatest
                                  ? glow.withValues(alpha: 0.2)
                                  : onBg.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            if (isCurrent)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: glow.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('INSTALADA', style: TextStyle(fontSize: r.footerSize - 3, color: glow, fontWeight: FontWeight.w700)),
                              )
                            else if (isLatest && tagClean != _currentVersion)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: glow.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('NUEVA', style: TextStyle(fontSize: r.footerSize - 3, color: glow, fontWeight: FontWeight.w700)),
                              ),
                            SizedBox(width: r.spacingS),
                            Text('v$tagClean', style: TextStyle(fontSize: r.subtitleSize - 1, fontWeight: FontWeight.w700, color: onBg)),
                            Spacer(),
                            Text(rel.date, style: TextStyle(fontSize: r.footerSize - 3, color: onBg.withValues(alpha: 0.4))),
                          ]),
                          if (rel.body.isNotEmpty) ...[
                            SizedBox(height: r.spacingXS),
                            Text(
                              _stripChangelog(rel.body),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.5), height: 1.3),
                            ),
                          ],
                          // Download button for any version that has an APK and is not current
                          if (!isCurrent && rel.downloadUrl.isNotEmpty) ...[
                            SizedBox(height: r.spacingS),
                            GestureDetector(
                              onTap: () {
                                if (isLatest && _updateInfo != null) {
                                  showUpdateModal(context, _updateInfo!);
                                } else {
                                  _downloadApk(rel.downloadUrl, tagClean);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: r.spacingS),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [glow, glow.withValues(alpha: 0.7)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(child: Text('Descargar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: r.footerSize))),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: r.bottomPadding),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadApk(String url, String version) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bitly_v$version.apk');
      final resp = await http.get(Uri.parse(url));
      await file.writeAsBytes(resp.bodyBytes);
      await OpenFilex.open(file.path);
    } catch (_) {}
  }

  String _stripChangelog(String body) {
    return body
        .replaceAll(RegExp(r'#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'\1')
        .replaceAll(RegExp(r'`'), '')
        .trim();
  }
}

class _ReleaseInfo {
  final String tag;
  final String body;
  final String date;
  final String downloadUrl;
  const _ReleaseInfo({required this.tag, required this.body, required this.date, this.downloadUrl = ''});
}