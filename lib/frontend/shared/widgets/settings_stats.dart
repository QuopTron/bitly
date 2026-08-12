import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'glass_container.dart';

class SettingsStorageSection extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  final AppLocalizations loc;

  const SettingsStorageSection({
    super.key,
    required this.onBg,
    required this.glowColor,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GlassContainer(
      borderRadius: 16, borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Row(children: [
        Icon(Icons.folder_outlined, color: glowColor, size: r.footerSize + 4),
        SizedBox(width: r.spacingS),
        Expanded(child: Text(loc.setup.downloadFolder, style: TextStyle(fontSize: r.subtitleSize, color: onBg))),
        Icon(Icons.chevron_right, color: onBg.withValues(alpha: 0.3), size: r.footerSize + 2),
      ]),
    );
  }
}

class SettingsStatsSection extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  final AppLocalizations loc;
  final String likedCount;
  final String downloadedCount;

  const SettingsStatsSection({
    super.key,
    required this.onBg,
    required this.glowColor,
    required this.loc,
    required this.likedCount,
    required this.downloadedCount,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GlassContainer(
      borderRadius: 16, borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Row(children: [
        _badge(r, Icons.favorite, Colors.red, likedCount, loc.setup.likedSongs),
        SizedBox(width: r.spacingM),
        _badge(r, Icons.download_done, const Color(0xFF4CAF50), downloadedCount, loc.setup.downloaded),
      ]),
    );
  }

  Widget _badge(Responsive r, IconData icon, Color color, String count, String label) {
    return Expanded(child: Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: r.footerSize, color: color),
        SizedBox(width: 4),
        Text(count, style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.bold, color: color)),
      ]),
      SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: r.footerSize - 2, color: Colors.white.withValues(alpha: 0.4))),
    ]));
  }
}


