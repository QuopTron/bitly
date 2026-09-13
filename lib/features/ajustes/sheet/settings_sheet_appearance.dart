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

/// Card de estilo visual con tiles Clásico / Spotify y controles granulares.
class _StylePicker extends StatelessWidget {
  final EstiloVisual estiloActual;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final AppLocalizations loc;
  final ValueChanged<EstiloVisual> onStyleChanged;

  const _StylePicker({
    required this.estiloActual,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.loc,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final prefs = EstiloHelper.preferencias(context);
    final esSpotify = estiloActual == EstiloVisual.spotify;

    return ContenedorVidrio(
      borderRadius: 16,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                color: glowColor,
                size: r.subtitleSize,
              ),
              SizedBox(width: r.spacingS),
              Text(
                'Estilo visual',
                style: TextStyle(
                  fontSize: r.subtitleSize,
                  fontWeight: FontWeight.w700,
                  color: onBg,
                ),
              ),
            ],
          ),
          SizedBox(height: r.spacingS),
          // ── Tiles: Clásico / Spotify ──
          Row(
            children: [
              Expanded(
                child: _ThemeTile(
                  icon: Icons.style,
                  label: 'Clásico',
                  selected: estiloActual == EstiloVisual.clasico,
                  glowColor: glowColor,
                  onBg: onBg,
                  r: r,
                  onTap: () => onStyleChanged(EstiloVisual.clasico),
                ),
              ),
              SizedBox(width: r.spacingS),
              Expanded(
                child: _ThemeTile(
                  icon: Icons.album_rounded,
                  label: 'Spotify',
                  selected: esSpotify,
                  glowColor: glowColor,
                  onBg: onBg,
                  r: r,
                  onTap: () => onStyleChanged(EstiloVisual.spotify),
                ),
              ),
            ],
          ),
          SizedBox(height: r.spacingXS),
          Text(
            esSpotify
                ? 'Personaliza qué componentes usan colores del cover.'
                : 'Activa Spotify para personalizar por componente.',
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: onBg.withValues(alpha: 0.4),
            ),
          ),
          // ── Controles granulares (solo visibles en modo Spotify) ──
          if (esSpotify) ...[
            SizedBox(height: r.spacingM),
            _SeccionGranular(
              glowColor: glowColor,
              onBg: onBg,
              r: r,
              prefs: prefs,
            ),
          ],
        ],
      ),
    );
  }
}

/// Sección de controles granulares por componente.
class _SeccionGranular extends StatelessWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final PreferenciasEstilo prefs;

  const _SeccionGranular({
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Componentes',
          style: TextStyle(
            fontSize: r.footerSize,
            fontWeight: FontWeight.w600,
            color: onBg.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: r.spacingS),
        _ToggleGranular(
          icon: Icons.music_note_rounded,
          label: 'Cards de canción',
          description: 'Color del cover en cada track',
          value: prefs.cardsCancion,
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          onChanged: (v) =>
              EstiloHelper.cambiarFlag(context, 'cardsCancion', v),
        ),
        _ToggleGranular(
          icon: Icons.album_rounded,
          label: 'Cards de grilla',
          description: 'Álbumes, playlists y artistas',
          value: prefs.cardsGrilla,
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          onChanged: (v) =>
              EstiloHelper.cambiarFlag(context, 'cardsGrilla', v),
        ),
        _ToggleGranular(
          icon: Icons.home_rounded,
          label: 'Fondo principal',
          description: 'Cover desenfocado en el home',
          value: prefs.fondoPrincipal,
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          onChanged: (v) =>
              EstiloHelper.cambiarFlag(context, 'fondoPrincipal', v),
        ),
        _ToggleGranular(
          icon: Icons.play_circle_filled_rounded,
          label: 'Fondo del reproductor',
          description: 'Cover desenfocado en NowPlaying',
          value: prefs.fondoReproductor,
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          onChanged: (v) =>
              EstiloHelper.cambiarFlag(context, 'fondoReproductor', v),
        ),
        _ToggleGranular(
          icon: Icons.web_asset_rounded,
          label: 'Fondos de modals',
          description: 'Settings, cola y letras',
          value: prefs.fondosModals,
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          onChanged: (v) =>
              EstiloHelper.cambiarFlag(context, 'fondosModals', v),
        ),
      ],
    );
  }
}

/// Toggle individual para un componente visual.
class _ToggleGranular extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final ValueChanged<bool> onChanged;

  const _ToggleGranular({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.spacingXS),
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: r.spacingS,
            vertical: r.spacingS,
          ),
          decoration: BoxDecoration(
            color: value
                ? glowColor.withValues(alpha: 0.08)
                : onBg.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value
                  ? glowColor.withValues(alpha: 0.25)
                  : onBg.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: r.footerSize + 4,
                color: value ? glowColor : onBg.withValues(alpha: 0.4),
              ),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: r.footerSize,
                        fontWeight: FontWeight.w600,
                        color: value ? onBg : onBg.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: r.footerSize - 2,
                        color: onBg.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  value
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  key: ValueKey(value),
                  size: 32,
                  color: value ? glowColor : onBg.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
