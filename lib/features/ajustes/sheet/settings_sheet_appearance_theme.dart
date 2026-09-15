// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_theme.dart — PART de settings_sheet_new.dart: selector de tema (Oscuro/Claro) con dos tiles grandes.
// Se conecta con: settings_sheet_new.dart (misma library) + settings_sheet_appearance_tile.
// Parte del flujo: Ajustes → Apariencia (tema).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

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
    return ContenedorVidrio(
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
