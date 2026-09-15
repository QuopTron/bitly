// ─────────────────────────────────────────────────────────────
// settings_sheet_sheet_build.dart — PART de settings_sheet_new.dart: cuerpo de la hoja — drag handle,
// settings_sheet_body_state.dart — PART de settings_sheet_new.dart: _SettingsSheetBodyState (movido desde settings_sheet_sheet_build.dart).
// Se conecta con: settings_sheet_new.dart (misma library).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

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
      // Más alto que la mitad: deja ~20% visible arriba (contexto de la
      // página) y le da más aire al contenido de cada pestaña.
      height: MediaQuery.of(context).size.height * 0.8,
      margin: EdgeInsets.only(top: r.spacingXL),
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
            // Objetivo del tutorial para el paso que explica las pestañas.
            KeyedSubtree(
              key: keyTutorialAjustesTabs,
              child: _BubbleTabsRow(
                currentIndex: widget.selectedTab,
                glowColor: glowColor,
                onBg: onBg,
                r: r,
                onTap: widget.onTabTap,
              ),
            ),
            SizedBox(height: r.spacingS),
            // Content: profile/stats when no tab selected, tab content
            // otherwise. La key es el objetivo de los pasos que explican
            // Descargas, Rendimiento y Más (el contenido cambia con la
            // pestaña que el tutorial va pidiendo).
            Expanded(
              child: KeyedSubtree(
                key: keyTutorialAjustesContenido,
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
                  onStyleChanged: widget.onStyleChanged,
                  onPremiumChanged: widget.onPremiumChanged,
                ),
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
            sigmaX:
                sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque,
            sigmaY:
                sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque,
          ),
          child: sheet,
        ),
      );
    }
    return sheet;
  }
}