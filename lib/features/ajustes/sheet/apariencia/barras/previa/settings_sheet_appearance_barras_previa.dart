// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_previa.dart — PART de
// settings_sheet_new.dart: la VISTA PREVIA del espacio Barras.
//
// Muestra el EJEMPLO de la barra que se está editando: si elegís navbar, ves
// el navbar; si elegís miniplayer, ves el miniplayer. Al cambiar de barra hace
// un crossfade (no se salta de una a la otra de golpe), y la etiqueta de abajo
// dice cuál estás viendo.
//
// Cada muestra lleva la forma, el adorno, el contorno y el color REALES de esa
// barra (ver _barras_previa_barra), así que mover el control se ve al instante.
//
// Se conecta con: settings_sheet_appearance_barras.dart (misma library) +
// _barras_previa_barra (lo que dibuja).
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Muestra la barra elegida, con un cambio suave al pasar de una a la otra.
class _VistaPreviaBarra extends StatelessWidget {
  final PreferenciasApariencia prefs;
  final bool navbar;
  final Responsive r;
  final Color onBg;
  final Color glowColor;
  final StringsApariencia t;

  const _VistaPreviaBarra({
    required this.prefs,
    required this.navbar,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.t,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: r.spacingL * 2.8,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 340),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder:
              (actual, anteriores) => Stack(
                alignment: Alignment.center,
                children: [...anteriores, if (actual != null) actual],
              ),
          child: _BarraEjemplo(
            key: ValueKey(navbar),
            navbar: navbar,
            prefs: prefs,
            r: r,
            onBg: onBg,
            glowColor: glowColor,
            // La previa muestra la barra que se está editando: va marcada.
            seleccionada: true,
          ),
        ),
      ),
      SizedBox(height: r.spacingXS),
      Text(
        navbar ? t.barras.navbar : t.barras.miniplayer,
        style: TextStyle(
          fontSize: r.footerSize - 2,
          fontWeight: FontWeight.w600,
          color: onBg.withValues(alpha: 0.5),
        ),
      ),
    ],
  );
}
