part of 'settings_sheet_new.dart';

/// Fila de bubble tabs (Apariencia, Descargas, Rendimiento, Más).
/// Cuatro burbujas con etiqueta pequeña; la activa brilla. Tocar la activa
/// de nuevo vuelve al perfil/estadísticas.
class _BubbleTabsRow extends StatelessWidget {
  final int currentIndex;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final void Function(int index) onTap;

  const _BubbleTabsRow({
    required this.currentIndex,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < _bubbleTabs.length; i++)
            _BubbleTab(
              index: i,
              active: currentIndex == i,
              glowColor: glowColor,
              onBg: onBg,
              r: r,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

/// Contenido de los tabs: cuando no hay tab seleccionado muestra el perfil
/// con estadísticas; si hay tab seleccionado, el TabBarView con los 4 tabs.
class _SettingsTabs extends StatelessWidget {
  final TabController controller;
  final int? selectedTab;
  final bool isDark;
  final Color glowColor;
  final PremiumStatus? premium;
  final String likedCount;
  final String downloadedCount;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLanguageChanged;
  final Future<void> Function() onPremiumChanged;

  const _SettingsTabs({
    required this.controller,
    required this.selectedTab,
    required this.isDark,
    required this.glowColor,
    required this.premium,
    required this.likedCount,
    required this.downloadedCount,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onPremiumChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedTab == null) {
      return _ProfileStatsView(
        glowColor: glowColor,
        likedCount: likedCount,
        downloadedCount: downloadedCount,
        premium: premium,
      );
    }

    return TabBarView(
      controller: controller,
      children: [
        _AppearanceTab(
          isDark: isDark,
          glowColor: glowColor,
          onThemeChanged: onThemeChanged,
          onLanguageChanged: onLanguageChanged,
        ),
        _DownloadsTab(glowColor: glowColor),
        _PerformanceTab(glowColor: glowColor),
        _MoreTab(
          glowColor: glowColor,
          premium: premium,
          onPremiumChanged: onPremiumChanged,
        ),
      ],
    );
  }
}
