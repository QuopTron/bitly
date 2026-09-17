// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance.dart — PART de settings_sheet_new.dart: pestaña Apariencia — selector de
// tema (Oscuro/Claro) y de estilo visual (Clásico/Spotify) con
// controles granulares por componente.
// Se conecta con: settings_sheet_new.dart (misma library) + tema.
// Parte del flujo: Ajustes → Apariencia.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Pickers del tab Apariencia: selector de tema (Oscuro/Claro) con dos
/// tiles grandes, selector de estilo visual (Clásico/Spotify) con
/// controles granulares por componente, y la sección de idioma.
class _AppearanceTab extends StatelessWidget {
  final bool isDark;
  final Color glowColor;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLanguageChanged;
  final ValueChanged<EstiloVisual> onStyleChanged;

  const _AppearanceTab({
    required this.isDark,
    required this.glowColor,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final loc = AppLocalizations.of(context);
    final estiloActual = EstiloHelper.actual(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Theme — LIVE segmented picker ──
          _ThemePicker(
            isDark: isDark,
            glowColor: glowColor,
            onBg: onBg,
            r: r,
            loc: loc,
            onThemeChanged: onThemeChanged,
          ),
          SizedBox(height: r.spacingS),
          // ── Visual style — Clásico / Spotify + granular ──
          _StylePicker(
            estiloActual: estiloActual,
            glowColor: glowColor,
            onBg: onBg,
            r: r,
            loc: loc,
            onStyleChanged: onStyleChanged,
          ),
          SizedBox(height: r.spacingS),
          // ── Diseño personalizable (borde, separación y redondeo) ──
          _DisenoCard(
            glowColor: glowColor,
            onBg: onBg,
            r: r,
            loc: loc,
          ),
          SizedBox(height: r.spacingS),
          // ── Language ──
          SettingsLanguageSection(
            onBg: onBg,
            glowColor: glowColor,
            loc: loc,
            onTap: onLanguageChanged,
            currentLanguage:
                loc.locale.languageCode == 'es' ? 'Español' : 'English',
          ),
        ],
      ),
    );
  }
}
