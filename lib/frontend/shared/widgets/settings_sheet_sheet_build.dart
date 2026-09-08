part of 'settings_sheet_new.dart';

/// Cuerpo del settings sheet: drag handle + perfil compacto + bubble tabs
/// + contenido (perfil/estadísticas o los 4 tabs). Recibe el estado del
/// sheet como parámetros para no depender del State padre.
class _SettingsSheetBody extends StatefulWidget {
  final TabController tabController;
  final int? selectedTab;
  final PremiumStatus? premium;
  final String username;
  final String likedCount;
  final String downloadedCount;
  final bool isDark;
  final Color glowColor;
  final Color onBg;
  final Color bg;
  final Responsive r;
  final bool hasTrack;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLanguageChanged;
  final Future<void> Function() onPremiumChanged;
  final void Function(int index) onTabTap;

  const _SettingsSheetBody({
    required this.tabController,
    required this.selectedTab,
    required this.premium,
    required this.username,
    required this.likedCount,
    required this.downloadedCount,
    required this.isDark,
    required this.glowColor,
    required this.onBg,
    required this.bg,
    required this.r,
    required this.hasTrack,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onPremiumChanged,
    required this.onTabTap,
  });

  @override
  State<_SettingsSheetBody> createState() => _SettingsSheetBodyState();
}

class _SettingsSheetBodyState extends State<_SettingsSheetBody> {
  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final isDark = widget.isDark;
    final onBg = widget.onBg;
    final glowColor = widget.glowColor;
    final bg = widget.bg;
    final hasTrack = widget.hasTrack;

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
              width: 40,
              height: 4,
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
              premium: widget.premium,
            ),
            SizedBox(height: r.spacingM),
            // Bubble tabs — Apariencia first. Four small circular bubbles
            // with a tiny label under each; the active one glows. No scroll,
            // no boxes.
            _BubbleTabsRow(
              currentIndex: widget.tabController.index,
              glowColor: glowColor,
              onBg: onBg,
              r: r,
              onTap: widget.onTabTap,
            ),
            SizedBox(height: r.spacingS),
            // Content: profile/stats when no tab selected, tab content otherwise.
            Expanded(
              child: _SettingsTabs(
                controller: widget.tabController,
                selectedTab: widget.selectedTab,
                isDark: isDark,
                glowColor: glowColor,
                premium: widget.premium,
                likedCount: widget.likedCount,
                downloadedCount: widget.downloadedCount,
                onThemeChanged: widget.onThemeChanged,
                onLanguageChanged: widget.onLanguageChanged,
                onPremiumChanged: widget.onPremiumChanged,
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
          filter: ImageFilter.blur(
            sigmaX: backdropBlurSigma,
            sigmaY: backdropBlurSigma,
          ),
          child: sheet,
        ),
      );
    }
    return sheet;
  }
}
