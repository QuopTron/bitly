part of 'settings_sheet_new.dart';

/// Pickers del tab Apariencia: selector de tema (Oscuro/Claro) con dos
/// tiles grandes y la sección de idioma (delegada a [SettingsLanguageSection]).
class _AppearanceTab extends StatelessWidget {
  final bool isDark;
  final Color glowColor;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLanguageChanged;

  const _AppearanceTab({
    required this.isDark,
    required this.glowColor,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final loc = AppLocalizations.of(context);

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

/// Card de tema con los dos tiles grandes Oscuro / Claro.
class _ThemePicker extends StatelessWidget {
  final bool isDark;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final AppLocalizations loc;
  final ValueChanged<bool> onThemeChanged;

  const _ThemePicker({
    required this.isDark,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.loc,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 16,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: glowColor,
                size: r.subtitleSize,
              ),
              SizedBox(width: r.spacingS),
              Text(
                loc.setup.theme,
                style: TextStyle(
                  fontSize: r.subtitleSize,
                  fontWeight: FontWeight.w700,
                  color: onBg,
                ),
              ),
            ],
          ),
          SizedBox(height: r.spacingS),
          // Two big pretty option tiles: Oscuro / Claro.
          Row(
            children: [
              Expanded(
                child: _ThemeTile(
                  icon: Icons.dark_mode_rounded,
                  label: loc.setup.darkMode,
                  selected: isDark,
                  glowColor: glowColor,
                  onBg: onBg,
                  r: r,
                  onTap: () {
                    if (!isDark) onThemeChanged(true);
                  },
                ),
              ),
              SizedBox(width: r.spacingS),
              Expanded(
                child: _ThemeTile(
                  icon: Icons.light_mode_rounded,
                  label: loc.setup.lightMode,
                  selected: !isDark,
                  glowColor: glowColor,
                  onBg: onBg,
                  r: r,
                  onTap: () {
                    if (isDark) onThemeChanged(false);
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: r.spacingXS),
          Text(
            'El cambio se aplica al instante en todas las vistas.',
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: onBg.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
