import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utils/responsive.dart';

class TabDef {
  final String label;
  final IconData icon;
  final int index;
  const TabDef(this.label, this.icon, this.index);
}

List<TabDef> buildTabs(AppLocalizations loc) => [
  TabDef(loc.setup.miSpaceSongs, Icons.music_note, 0),
  TabDef(loc.setup.miSpacePlaylists, Icons.queue_music, 1),
  TabDef(loc.setup.miSpaceAlbums, Icons.album, 2),
  TabDef(loc.setup.miSpaceArtists, Icons.person, 3),
];

class MiEspacioTabBar extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final Color onBg;
  final Color glowColor;

  const MiEspacioTabBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    final tabs = buildTabs(loc);

    return Padding(
      padding: EdgeInsets.fromLTRB(r.spacingS, r.spacingM, r.spacingS, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(tabs.length, (i) {
          final t = tabs[i];
          final sel = selectedTab == i;
          return Padding(
            padding: EdgeInsets.only(right: r.spacingXS),
            child: GestureDetector(
              onTap: () => onTabChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: sel ? glowColor.withValues(alpha: 0.15) : Colors.transparent,
                  border: Border.all(
                    color: sel ? glowColor.withValues(alpha: 0.5) : onBg.withValues(alpha: 0.1),
                    width: sel ? 1.0 : 0.6,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.icon, size: r.footerSize + 1,
                    color: sel ? glowColor : onBg.withValues(alpha: 0.45)),
                  SizedBox(width: r.spacingXS),
                  Text(t.label,
                    style: TextStyle(
                      fontSize: r.footerSize,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      color: sel ? glowColor : onBg.withValues(alpha: 0.45))),
                ]),
              ),
            ),
          );
        })),
      ),
    );
  }
}


