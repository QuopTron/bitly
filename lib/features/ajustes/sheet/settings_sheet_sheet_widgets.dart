// ─────────────────────────────────────────────────────────────
// settings_sheet_sheet_widgets.dart — PART de settings_sheet_new.dart: fila de pestañas burbuja y el
// contenedor que alterna entre perfil/estadísticas y las 4 pestañas.
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: Ajustes (pestañas burbuja).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Fila de bubble tabs (Apariencia, Descargas, Rendimiento, Más).
/// Cuatro burbujas con etiqueta pequeña; la activa brilla. Tocar la activa
/// de nuevo vuelve al perfil/estadísticas.
class _BubbleTabsRow extends StatelessWidget {
  final int? currentIndex;
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
      // Padding parejo y chico: con 5 burbujas, el padding grande dejaba las
      // últimas dos (Rendimiento y Estadísticas) pegadas al borde y fuera de
      // eje respecto de las primeras.
      padding: EdgeInsets.symmetric(horizontal: r.spacingS),
      child: Row(
        // Sin spaceEvenly: cada burbuja ya ocupa un Expanded igual, y sumar
        // reparto por espacios libres corría el eje cuando las etiquetas
        // tenían distinto ancho.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _bubbleTabs.length; i++)
            Expanded(
              child: _BubbleTab(
                index: i,
                active: currentIndex == i,
                glowColor: glowColor,
                onBg: onBg,
                r: r,
                onTap: () => onTap(i),
              ),
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
  final EstadoPremium? premium;
  final String likedCount;
  final String downloadedCount;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLanguageChanged;
  final ValueChanged<EstiloVisual> onStyleChanged;
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
    required this.onStyleChanged,
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
          onStyleChanged: onStyleChanged,
        ),
        _DownloadsTab(glowColor: glowColor),
        // ORDEN = el de las burbujas (settings_sheet_entry): Rendimiento en la
        // tercera y Estadísticas en la cuarta. Estaban invertidas, así que cada
        // burbuja abría la pestaña de la otra.
        _PerformanceTab(glowColor: glowColor),
        _CompartidosTab(glowColor: glowColor),
        _MoreTab(
          glowColor: glowColor,
          premium: premium,
          onPremiumChanged: onPremiumChanged,
        ),
      ],
    );
  }
}
