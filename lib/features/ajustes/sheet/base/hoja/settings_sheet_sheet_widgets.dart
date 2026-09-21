// ─────────────────────────────────────────────────────────────
// settings_sheet_sheet_widgets.dart — PART de settings_sheet_new.dart: el
// contenedor que alterna entre perfil/estadísticas y las pestañas.
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: Ajustes (contenido de las pestañas).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Contenido de los tabs: cuando no hay tab seleccionado muestra el perfil
/// con estadísticas; si hay tab seleccionado, el TabBarView con las pestañas.
class _SettingsTabs extends StatelessWidget {
  final TabController controller;
  final int? selectedTab;
  final bool isDark;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final EstadoPremium? premium;
  final String likedCount;
  final String downloadedCount;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function() onPremiumChanged;

  const _SettingsTabs({
    required this.controller,
    required this.selectedTab,
    required this.isDark,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.premium,
    required this.likedCount,
    required this.downloadedCount,
    required this.onThemeChanged,
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
        ),
        _DownloadsTab(glowColor: glowColor),
        // ORDEN = el de las burbujas (settings_sheet_entry): Rendimiento en la
        // tercera y Estadísticas en la cuarta. Estaban invertidas, así que cada
        // burbuja abría la pestaña de la otra.
        _PerformanceTab(glowColor: glowColor),
        _CompartidosTab(glowColor: glowColor),
        // Cuenta y Proveedores salieron de "Más": cada burbuja tiene su tema
        // y Más deja de ser un cajón de sastre.
        _CuentaTab(
          glowColor: glowColor,
          premium: premium,
          onPremiumChanged: onPremiumChanged,
        ),
        _ProveedoresTab(glowColor: glowColor),
        _ConexionTab(glowColor: glowColor, onBg: onBg, r: r),
        _MoreTab(glowColor: glowColor),
      ],
    );
  }
}
