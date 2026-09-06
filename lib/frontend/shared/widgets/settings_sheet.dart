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
import 'settings_download_priority_section.dart';
import 'update_modal.dart';

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
    final onBg = AppColors.onSurface(widget.isDark);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(widget.isDark),
        title: Text(loc.setup.resetDataTitle, style: TextStyle(color: onBg)),
        content: Text(loc.setup.resetDataMessage, style: TextStyle(color: onBg.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.setup.cancel, style: TextStyle(color: onBg.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.setup.confirm, style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
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
  Widget _sectionLabel(String label, Color onBg, Responsive r, {IconData? icon}) {
    return Padding(
      padding: EdgeInsets.only(left: r.spacingXL + r.spacingS, top: r.spacingL, bottom: r.spacingXS),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: r.footerSize + 1, color: onBg.withValues(alpha: 0.25)),
            SizedBox(width: r.spacingXS),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: r.footerSize - 1,
              fontWeight: FontWeight.w600,
              color: onBg.withValues(alpha: 0.35),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    final onBg = AppColors.onSurface(widget.isDark);
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Container(
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: AppColors.surface(widget.isDark),
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
            // ── Profile ──────────────────────────────────────
            SettingsProfileSection(username: widget.username, onBg: onBg, glowColor: glowColor, loc: loc),
            _sectionLabel(loc.setup.theme, onBg, r, icon: Icons.palette_outlined),
            SettingsThemeSection(
              isDark: widget.isDark, onBg: onBg, glowColor: glowColor, loc: loc,
              onToggle: () => widget.onThemeChanged(!widget.isDark),
            ),
            SizedBox(height: r.spacingS),
            SettingsLanguageSection(
              onBg: onBg, glowColor: glowColor, loc: loc, onTap: widget.onLanguageChanged,
              currentLanguage: loc.locale.languageCode == 'es' ? 'Español' : 'English',
            ),
            _sectionLabel(loc.setup.settingsDownloadsLabel, onBg, r, icon: Icons.download_rounded),
            SettingsStorageSection(onBg: onBg, glowColor: glowColor, loc: loc),
            SizedBox(height: r.spacingS),
            SettingsDownloadSection(onBg: onBg, glowColor: glowColor),
            SizedBox(height: r.spacingS),
            SettingsDownloadPrioritySection(onBg: onBg, glowColor: glowColor),
            _sectionLabel(loc.setup.settingsPerformanceLabel, onBg, r, icon: Icons.speed_rounded),
            SettingsPerformanceSection(onBg: onBg, glowColor: glowColor),
            _sectionLabel(loc.setup.settingsServicesLabel, onBg, r, icon: Icons.extension_rounded),
            SettingsProviderSection(onBg: onBg, glowColor: glowColor),
            SizedBox(height: r.spacingS),
            SettingsCacheSection(onBg: onBg, glowColor: glowColor),
            SizedBox(height: r.spacingM),
            SettingsResetSection(
              onBg: onBg, glowColor: glowColor, loc: loc,
              onTap: _confirmReset, resetting: _resetting,
            ),
            _sectionLabel(loc.setup.settingsStatsLabel, onBg, r, icon: Icons.bar_chart_rounded),
            SettingsStatsSection(
              onBg: onBg, glowColor: glowColor, loc: loc,
              likedCount: widget.likedCount, downloadedCount: widget.downloadedCount,
            ),
            SizedBox(height: r.spacingM),
            // ── Update check ─────────────────────────────────
            _UpdateCheckButton(onBg: onBg, glowColor: glowColor),
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

class _UpdateCheckButton extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  const _UpdateCheckButton({required this.onBg, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingL),
      child: GestureDetector(
        onTap: () async {
          final info = await UpdateService().checkForUpdate();
          if (info != null && context.mounted) {
            showUpdateModal(context, info);
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'Estás en la última versión'
                      : 'You are on the latest version',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
          decoration: BoxDecoration(
            color: onBg.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: onBg.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.system_update, size: r.subtitleSize + 2, color: glowColor),
              SizedBox(width: r.spacingS),
              Text(
                Theme.of(context).brightness == Brightness.dark
                    ? 'Buscar actualizaciones'
                    : 'Check for updates',
                style: TextStyle(
                  fontSize: r.subtitleSize,
                  fontWeight: FontWeight.w600,
                  color: onBg.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


