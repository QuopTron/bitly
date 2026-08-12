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
import '../../features/setup/setup_page.dart';
import '../../../injection.dart';
import 'settings_sections.dart';
import 'settings_stats.dart';
import 'settings_download_section.dart';
import 'settings_cache_section.dart';
import 'settings_provider_section.dart';
import 'settings_performance_section.dart';

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

class _SettingsSheetState extends State<SettingsSheet> {
  bool _resetting = false;

  Future<void> _confirmReset() async {
    final loc = AppLocalizations.of(context);
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        title: Text(loc.setup.resetDataTitle, style: TextStyle(color: onBg)),
        content: Text(loc.setup.resetDataMessage, style: TextStyle(color: onBg.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.setup.cancel, style: TextStyle(color: onBg.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.setup.confirm, style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _resetting = true);

    try {
      // 1. Reset the Go backend database
      await sl<BackendService>().resetAllData();

      // 2. Clear all Flutter-side local storage
      (await SharedPreferences.getInstance()).clear();

      // 3. Reset in-memory cubits — reload from empty backend
      if (mounted) {
        context.read<LikeCubit>().initialize();
        context.read<DownloadCubit>().initialize();
        context.read<PlaylistCubit>().initialize();
      }

      // 4. Close the settings sheet
      if (mounted) Navigator.pop(context);

      // 5. Navigate to setup screen
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
    final loc = AppLocalizations.of(context);
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Container(
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(height: r.spacingM),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: onBg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            SizedBox(height: r.spacingL),
            Text(loc.setup.settings, style: TextStyle(fontSize: r.subtitleSize + 2, fontWeight: FontWeight.bold, color: onBg)),
            SizedBox(height: r.spacingL),
            SettingsProfileSection(username: widget.username, onBg: onBg, glowColor: glowColor, loc: loc),
            SizedBox(height: r.spacingM),
            SettingsThemeSection(
              isDark: widget.isDark, onBg: onBg, glowColor: glowColor, loc: loc,
              onToggle: () => widget.onThemeChanged(!widget.isDark),
            ),
            SizedBox(height: r.spacingM),
            SettingsLanguageSection(
              onBg: onBg, glowColor: glowColor, loc: loc, onTap: widget.onLanguageChanged,
              currentLanguage: loc.locale.languageCode == 'es' ? 'Español' : 'English',
            ),
            SizedBox(height: r.spacingM),
            SettingsStorageSection(onBg: onBg, glowColor: glowColor, loc: loc),
            SizedBox(height: r.spacingM),
            SettingsDownloadSection(onBg: onBg, glowColor: glowColor),
            SizedBox(height: r.spacingM),
            SettingsPerformanceSection(onBg: onBg, glowColor: glowColor),
            SizedBox(height: r.spacingM),
            SettingsProviderSection(onBg: onBg, glowColor: glowColor),
            SizedBox(height: r.spacingM),
            SettingsCacheSection(onBg: onBg, glowColor: glowColor),
            SizedBox(height: r.spacingM),
            SettingsResetSection(
              onBg: onBg, glowColor: glowColor, loc: loc,
              onTap: _confirmReset, resetting: _resetting,
            ),
            SizedBox(height: r.spacingM),
            SettingsStatsSection(
              onBg: onBg, glowColor: glowColor, loc: loc,
              likedCount: widget.likedCount, downloadedCount: widget.downloadedCount,
            ),
            SizedBox(height: r.spacingXL),
          ]),
        ),
      ),
    );
  }
}

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


