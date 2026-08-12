import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utils/responsive.dart';
import '../../shared/widgets/settings_sheet.dart';

class MiEspacioProfile extends StatelessWidget {
  final String username;
  final int lovedSongsCount;
  final int playlistsCount;
  final int downloadedCount;
  final int level;
  final double levelProgress;
  final int nextLevel;
  final Color onBg;
  final Color glowColor;
  final ValueChanged<bool>? onThemeChanged;
  final VoidCallback? onLanguageChanged;

  const MiEspacioProfile({
    super.key,
    required this.username,
    required this.lovedSongsCount,
    required this.playlistsCount,
    this.downloadedCount = 0,
    this.level = 0,
    this.levelProgress = 0.0,
    this.nextLevel = 1,
    required this.onBg,
    required this.glowColor,
    this.onThemeChanged,
    this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);
    final avatarSize = r.titleSize * 2.2;
    final displayName = username.isNotEmpty ? username : loc.setup.miSpaceGuest;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: Column(children: [
        Row(children: [
          Container(
            width: avatarSize, height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [glowColor.withValues(alpha: 0.35), glowColor.withValues(alpha: 0.1)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              border: Border.all(color: glowColor.withValues(alpha: 0.45), width: 2),
              boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 2))],
            ),
            child: Icon(Icons.person, size: avatarSize * 0.45, color: onBg.withValues(alpha: 0.5)),
          ),
          SizedBox(width: r.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                  style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg)),
                SizedBox(height: 2),
                Text('$lovedSongsCount ${loc.setup.miSpaceSongCount}  •  $playlistsCount ${loc.setup.miSpacePlaylistCount}',
                  style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.4))),
              ]),
          ),
          if (lovedSongsCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 4),
              decoration: BoxDecoration(
                color: glowColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.favorite, size: r.footerSize, color: glowColor),
                SizedBox(width: 4),
                Text('$lovedSongsCount',
                  style: TextStyle(fontSize: r.footerSize - 1, fontWeight: FontWeight.w600, color: glowColor)),
              ]),
            ),
          if (onThemeChanged != null)
            GestureDetector(
              onTap: () {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                showSettingsSheet(context,
                  username: username,
                  isDark: isDark,
                  onThemeChanged: onThemeChanged!,
                  onLanguageChanged: onLanguageChanged ?? () {},
                  likedCount: '$lovedSongsCount',
                  downloadedCount: '$downloadedCount',
                );
              },
              child: Padding(
                padding: EdgeInsets.only(left: r.spacingS),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: onBg.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.settings, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.5)),
                ),
              ),
            ),
        ]),
        // ── Level / Progress Bar ─────────────────────────────────
        if (level > 0) ...[
          SizedBox(height: r.spacingS),
          Row(children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: glowColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome, size: r.footerSize - 2, color: glowColor),
                SizedBox(width: 4),
                Text('${loc.setup.level} $level',
                  style: TextStyle(
                    fontSize: r.footerSize - 1, fontWeight: FontWeight.w600, color: glowColor)),
              ]),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: levelProgress.clamp(0.0, 1.0),
                    backgroundColor: onBg.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(glowColor.withValues(alpha: 0.6)),
                    minHeight: 6,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${(levelProgress * 100).toInt()}% → ${loc.setup.nextLevel} $nextLevel',
                  style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.35)),
                ),
              ]),
            ),
          ]),
        ],
      ]),
    );
  }
}


