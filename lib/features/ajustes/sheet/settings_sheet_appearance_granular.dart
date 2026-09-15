// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_granular.dart — PART de settings_sheet_new.dart: controles granulares por componente (cards, fondos) del estilo Spotify.
// Se conecta con: settings_sheet_new.dart (misma library) + estilo_helper.
// Parte del flujo: Ajustes → Apariencia (componentes).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

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
