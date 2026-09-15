// ─────────────────────────────────────────────────────────────
// settings_sheet_sheet_build.dart — PART de settings_sheet_new.dart: cuerpo de la hoja — drag handle,
// perfil compacto, pestañas burbuja y contenido de cada pestaña.
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: Ajustes (cuerpo de la hoja).
// ─────────────────────────────────────────────────────────────


part of 'settings_sheet_new.dart';


/// Cuerpo del settings sheet: drag handle + perfil compacto + bubble tabs
/// + contenido (perfil/estadísticas o los 4 tabs). Recibe el estado del
/// sheet como parámetros para no depender del State padre.
class _SettingsSheetBody extends StatefulWidget {
  final TabController tabController;
  final int? selectedTab;
  final EstadoPremium? premium;
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
  final ValueChanged<EstiloVisual> onStyleChanged;
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
    required this.onStyleChanged,
    required this.onPremiumChanged,
    required this.onTabTap,
  });

  @override
  State<_SettingsSheetBody> createState() => _SettingsSheetBodyState();
}