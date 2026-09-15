// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_style.dart — PART de settings_sheet_new.dart: selector de estilo visual (Clásico/Spotify) con los controles granulares cuando aplica.
// Se conecta con: settings_sheet_new.dart (misma library) + settings_sheet_appearance_tile + appearance_granular.
// Parte del flujo: Ajustes → Apariencia (estilo).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

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
