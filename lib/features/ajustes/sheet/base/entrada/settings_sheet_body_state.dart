// ─────────────────────────────────────────────────────────────
// settings_sheet_body_state.dart — PART de settings_sheet_new.dart: el cuerpo
// de la hoja de Ajustes. Arma los tres slots (cabecera con el perfil,
// navegación y contenido) y los entrega al armado por plataforma.
//
// El armado en sí NO vive acá: cada plataforma tiene su archivo y su diseño
// (celular, PC y TV), elegidos por `varianteAjustes` en vistas/base/
// ajustes_marco.dart — que pregunta TV PRIMERO, porque una tele ancha también
// entra en el layout de escritorio. Así esta pieza deja de tener ternarios por
// plataforma: sólo decide QUÉ se muestra, no CÓMO se ubica.
//
// Se conecta con: vistas/base/ajustes_marco.dart (el armado) +
// settings_sheet_nav.dart (navegación) + settings_sheet_sheet_widgets.dart
// (contenido).
// Parte del flujo: Ajustes (cuerpo de la hoja).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

class _SettingsSheetBodyState extends State<_SettingsSheetBody> {
  @override
  Widget build(BuildContext context) {
    // Declarado con su tipo para que se vea que la hoja mide por APARATO: en
    // la tele todo esto crece (ver responsive.dart).
    final Responsive r = widget.r;
    final isDark = widget.isDark;
    final onBg = widget.onBg;

    final marco = MarcoAjustes(
      r: r,
      isDark: isDark,
      hasTrack: widget.hasTrack,
      bg: widget.bg,
      onBg: onBg,
      // Perfil compacto (siempre visible, en las tres variantes).
      cabecera: _ProfileHeader(
        username: widget.username,
        glowColor: widget.glowColor,
        likedCount: widget.likedCount,
        downloadedCount: widget.downloadedCount,
        premium: widget.premium,
      ),
      // Navegación: burbujas en celular, riel en pantalla ancha (y el riel de
      // TV en la tele). La key es el objetivo del paso que explica las
      // pestañas.
      navegacion: KeyedSubtree(
        key: keyTutorialAjustesTabs,
        child: _NavAjustes(
          currentIndex: widget.selectedTab,
          glowColor: widget.glowColor,
          onBg: onBg,
          r: r,
          onTap: widget.onTabTap,
        ),
      ),
      // Contenido: perfil/estadísticas cuando no hay pestaña elegida, o los
      // tabs. La key es el objetivo de los pasos que explican cada pestaña
      // (el contenido cambia con la pestaña que el tutorial va pidiendo).
      contenido: KeyedSubtree(
        key: keyTutorialAjustesContenido,
        child: _SettingsTabs(
          controller: widget.tabController,
          selectedTab: widget.selectedTab,
          isDark: isDark,
          glowColor: widget.glowColor,
          onBg: onBg,
          r: r,
          premium: widget.premium,
          likedCount: widget.likedCount,
          downloadedCount: widget.downloadedCount,
          onThemeChanged: widget.onThemeChanged,
          onPremiumChanged: widget.onPremiumChanged,
        ),
      ),
    );

    return MarcoAjustesVista(marco: marco);
  }
}
