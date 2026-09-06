import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../backend/rpc/backend_service.dart';
import '../utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/download_cubit.dart';
import '../../../backend/services/playlist_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../features/setup/setup_page.dart';
import '../../../injection.dart';
import 'glass_container.dart';
import 'settings_sections.dart';
import 'settings_download_section.dart';
import 'settings_cache_section.dart';
import 'settings_provider_section.dart';
import 'settings_performance_section.dart';
import 'settings_download_priority_section.dart';
import 'settings_stats.dart';
import 'update_modal.dart';

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
    builder: (_) => SettingsSheet(
      username: username, isDark: isDark,
      onThemeChanged: onThemeChanged,
      onLanguageChanged: onLanguageChanged,
      likedCount: likedCount, downloadedCount: downloadedCount,
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
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmReset() async {
    final loc = AppLocalizations.of(context);
    final onBg = AppColors.onSurface(widget.isDark);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(widget.isDark),
        title: Text(loc.setup.resetDataTitle, style: TextStyle(color: onBg)),
        content: Text(loc.setup.resetDataMessage,
            style: TextStyle(color: onBg.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.setup.cancel, style: TextStyle(color: onBg.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.setup.confirm,
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resetting = true);
    try {
      await sl<BackendService>().resetAllData();
      (await SharedPreferences.getInstance()).clear();
      if (mounted) {
        context.read<LikeCubit>().initialize();
        context.read<DownloadCubit>().initialize();
        context.read<PlaylistCubit>().initialize();
      }
      if (mounted) Navigator.pop(context);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SetupPage()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = AppColors.onSurface(widget.isDark);
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;
    final hasTrack = sl<QueueCubit>().state.hasCurrent;
    final bg = AppColors.surface(widget.isDark);

    Widget sheet = Container(
      height: MediaQuery.of(context).size.height * 0.65,
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: hasTrack ? bg.withValues(alpha: 0.75) : bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            SizedBox(height: r.spacingS),
            // Tab bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: glowColor,
              unselectedLabelColor: onBg.withValues(alpha: 0.4),
              labelStyle: TextStyle(fontSize: r.footerSize, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(fontSize: r.footerSize),
              indicatorColor: glowColor,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.symmetric(horizontal: r.spacingS),
              tabs: const [
                Tab(icon: Icon(Icons.person_outline), text: 'Profile'),
                Tab(icon: Icon(Icons.play_circle_outline), text: 'Play'),
                Tab(icon: Icon(Icons.download_rounded), text: 'Downloads'),
                Tab(icon: Icon(Icons.palette_outlined), text: 'Theme'),
                Tab(icon: Icon(Icons.more_horiz), text: 'More'),
              ],
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ProfileTab(
                    username: widget.username,
                    glowColor: glowColor,
                    likedCount: widget.likedCount,
                    downloadedCount: widget.downloadedCount,
                  ),
                  _PlaybackTab(glowColor: glowColor),
                  _DownloadsTab(glowColor: glowColor),
                  _AppearanceTab(
                    isDark: widget.isDark, glowColor: glowColor,
                    onThemeChanged: widget.onThemeChanged,
                    onLanguageChanged: widget.onLanguageChanged,
                  ),
                  _MoreTab(
                    isDark: widget.isDark, glowColor: glowColor,
                    resetting: _resetting, onReset: _confirmReset,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: sheet,
        ),
      );
    }
    return sheet;
  }
}

// ═══════════════════════════════════════════════════════
//  TAB: Profile
// ═══════════════════════════════════════════════════════
class _ProfileTab extends StatefulWidget {
  final String username;
  final Color glowColor;
  final String likedCount;
  final String downloadedCount;

  const _ProfileTab({
    required this.username,
    required this.glowColor,
    required this.likedCount,
    required this.downloadedCount,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final raw = await sl<BackendService>().rpcCall('getPlaybackStats', {});
      if (raw is Map && mounted) {
        setState(() => _stats = Map<String, dynamic>.from(raw));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = AppColors.onSurface(Theme.of(context).brightness == Brightness.dark);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        children: [
          SizedBox(height: r.spacingS),
          // Avatar with glow
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.glowColor, widget.glowColor.withValues(alpha: 0.5)],
              ),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: widget.glowColor.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)],
            ),
            child: Center(
              child: Text(
                widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          SizedBox(height: r.spacingM),
          Text(
            widget.username.isNotEmpty ? widget.username : 'Guest',
            style: TextStyle(fontSize: r.subtitleSize + 4, fontWeight: FontWeight.bold, color: onBg),
          ),
          SizedBox(height: r.spacingXS),
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
            decoration: BoxDecoration(
              color: widget.glowColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.glowColor.withValues(alpha: 0.25)),
            ),
            child: Text('✦ Premium', style: TextStyle(fontSize: r.footerSize - 1, color: widget.glowColor, fontWeight: FontWeight.w600)),
          ),
          SizedBox(height: r.spacingXL),
          // Stats grid
          _statsGrid(r, onBg),
          SizedBox(height: r.spacingL),
          // Favorite track
          _topTrackCard(r, onBg),
        ],
      ),
    );
  }

  Widget _statsGrid(Responsive r, Color onBg) {
    final cards = [
      _stat(Icons.favorite, Colors.redAccent, widget.likedCount, 'Liked'),
      _stat(Icons.download_done, const Color(0xFF4CAF50), widget.downloadedCount, 'Downloaded'),
      _stat(Icons.play_circle, widget.glowColor, '${_stats['totalPlays'] ?? 0}', 'Plays'),
      _stat(Icons.library_music, Colors.orangeAccent, '${_stats['uniqueTracks'] ?? 0}', 'Unique'),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
      mainAxisSpacing: r.spacingS, crossAxisSpacing: r.spacingS, childAspectRatio: 2.2,
      children: cards,
    );
  }

  Widget _stat(IconData icon, Color color, String value, String label) {
    final r = Responsive(context);
    final onBg = AppColors.onSurface(Theme.of(context).brightness == Brightness.dark);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onBg.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        Icon(icon, size: r.footerSize + 4, color: color),
        SizedBox(width: r.spacingS),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.bold, color: onBg)),
          Text(label, style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.45))),
        ]),
      ]),
    );
  }

  Widget _topTrackCard(Responsive r, Color onBg) {
    final topTrack = _stats['topTrack'];
    if (topTrack is! Map) return const SizedBox.shrink();
    final name = (topTrack['name'] ?? '').toString();
    final artist = (topTrack['artist'] ?? '').toString();
    if (name.isEmpty) return const SizedBox.shrink();

    return GlassContainer(
      borderRadius: 14, borderColor: onBg.withValues(alpha: 0.08), bgColor: onBg.withValues(alpha: 0.04),
      padding: EdgeInsets.all(r.spacingM),
      child: Row(children: [
        Icon(Icons.emoji_events, color: Colors.amber, size: r.subtitleSize + 4),
        SizedBox(width: r.spacingM),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FAVORITE TRACK', style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.4), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          SizedBox(height: 2),
          Text(name, style: TextStyle(fontSize: r.subtitleSize - 1, fontWeight: FontWeight.w600, color: onBg), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(artist, style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.5)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB: Playback
// ═══════════════════════════════════════════════════════
class _PlaybackTab extends StatelessWidget {
  final Color glowColor;
  const _PlaybackTab({required this.glowColor});

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
          _sectionLabel('AUDIO QUALITY', Icons.high_quality, onBg, r),
          SizedBox(height: r.spacingS),
          SettingsDownloadSection(onBg: onBg, glowColor: glowColor),
          SizedBox(height: r.spacingL),
          _sectionLabel('CROSSFADE', Icons.swap_horiz, onBg, r),
          SizedBox(height: r.spacingS),
          GlassContainer(
            borderRadius: 16, borderColor: onBg.withValues(alpha: 0.08), bgColor: onBg.withValues(alpha: 0.03),
            padding: EdgeInsets.all(r.spacingM),
            child: Row(children: [
              Icon(Icons.swap_horiz, color: glowColor, size: r.footerSize + 4),
              SizedBox(width: r.spacingS),
              Expanded(child: Text('Crossfade', style: TextStyle(fontSize: r.subtitleSize - 1, color: onBg))),
              Switch(value: true, onChanged: (v) {}, activeTrackColor: glowColor.withValues(alpha: 0.3), activeThumbColor: glowColor),
            ]),
          ),
          SizedBox(height: r.spacingL),
          _sectionLabel('PLAYBACK MODE', Icons.repeat, onBg, r),
          SizedBox(height: r.spacingS),
          _modeCard(r, onBg, Icons.repeat, 'Repeat Off'),
          SizedBox(height: r.spacingXS),
          _modeCard(r, onBg, Icons.repeat_one, 'Repeat One'),
          SizedBox(height: r.spacingXS),
          _modeCard(r, onBg, Icons.repeat, 'Repeat All'),
        ],
      ),
    );
  }

  Widget _modeCard(Responsive r, Color onBg, IconData icon, String label) {
    return GlassContainer(
      borderRadius: 14, borderColor: onBg.withValues(alpha: 0.08), bgColor: onBg.withValues(alpha: 0.03),
      padding: EdgeInsets.all(r.spacingM),
      child: Row(children: [
        Icon(icon, color: onBg.withValues(alpha: 0.5), size: r.footerSize + 4),
        SizedBox(width: r.spacingS),
        Expanded(child: Text(label, style: TextStyle(fontSize: r.subtitleSize - 1, color: onBg))),
        Icon(Icons.chevron_right, color: onBg.withValues(alpha: 0.3), size: r.footerSize + 2),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB: Downloads
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
          SettingsDownloadSection(onBg: onBg, glowColor: glowColor),
          SizedBox(height: r.spacingS),
          SettingsDownloadPrioritySection(onBg: onBg, glowColor: glowColor),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB: Appearance
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
          SizedBox(height: r.spacingS),
          SettingsThemeSection(
            isDark: isDark, onBg: onBg, glowColor: glowColor, loc: loc,
            onToggle: () => onThemeChanged(!isDark),
          ),
          SizedBox(height: r.spacingS),
          SettingsLanguageSection(
            onBg: onBg, glowColor: glowColor, loc: loc,
            onTap: onLanguageChanged,
            currentLanguage: loc.locale.languageCode == 'es' ? 'Español' : 'English',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB: More
// ═══════════════════════════════════════════════════════
class _MoreTab extends StatelessWidget {
  final bool isDark;
  final Color glowColor;
  final bool resetting;
  final VoidCallback onReset;

  const _MoreTab({
    required this.isDark,
    required this.glowColor,
    required this.resetting,
    required this.onReset,
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
          SizedBox(height: r.spacingS),
          SettingsPerformanceSection(onBg: onBg, glowColor: glowColor),
          SizedBox(height: r.spacingS),
          SettingsProviderSection(onBg: onBg, glowColor: glowColor),
          SizedBox(height: r.spacingS),
          SettingsCacheSection(onBg: onBg, glowColor: glowColor),
          SizedBox(height: r.spacingM),
          SettingsResetSection(
            onBg: onBg, glowColor: glowColor, loc: loc,
            onTap: onReset, resetting: resetting,
          ),
          SizedBox(height: r.spacingL),
          _updateButton(context, r, onBg, glowColor),
          SizedBox(height: r.spacingL),
        ],
      ),
    );
  }

  Widget _updateButton(BuildContext context, Responsive r, Color onBg, Color glow) {
    return GestureDetector(
      onTap: () async {
        final info = await UpdateService().checkForUpdate();
        if (info != null && context.mounted) {
          showUpdateModal(context, info);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('You are on the latest version'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: onBg.withValues(alpha: 0.1)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.system_update, size: r.subtitleSize + 2, color: glow),
          SizedBox(width: r.spacingS),
          Text('Check for updates', style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg.withValues(alpha: 0.7))),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Shared helpers
// ═══════════════════════════════════════════════════════
Widget _sectionLabel(String label, IconData icon, Color onBg, Responsive r) {
  return Row(
    children: [
      Icon(icon, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.3)),
      SizedBox(width: r.spacingXS),
      Text(label, style: TextStyle(fontSize: r.footerSize, fontWeight: FontWeight.w600, color: onBg.withValues(alpha: 0.4), letterSpacing: 0.5)),
    ],
  );
}
