// ─────────────────────────────────────────────────────────────
// barra_navegacion_lateral.dart — Barra lateral fija del LAYOUT DE
// ESCRITORIO (PC/web/pantallas anchas): logo, 3 secciones (Buscar,
// Inicio, Mi Espacio) con hover animado (fondo + escala del icono)
// e indicador de selección con barra lateral, y espacio para el
// perfil/ajustes al final. Sustituye a la navbar flotante inferior
// del móvil. Ancho fijo 240px con vidrio sobre el fondo ambiente.
// Se conecta con: home_escritorio.dart (navegación) + shared (vidrio,
// tema, responsive).
// Parte del flujo: Home (navegación de secciones en escritorio).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/tema/colores_app.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../shared/widgets/vidrio/base/contenedor_vidrio.dart';
import 'barra_lateral_item.dart';

/// Ancho fijo de la barra lateral de escritorio.
const double anchoBarraLateral = 240;

/// Barra lateral de navegación del escritorio.
class BarraNavegacionLateral extends StatelessWidget {
  final bool isDark;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BarraNavegacionLateral({
    super.key,
    required this.isDark,
    required this.currentIndex,
    required this.onTap,
  });

  static const _icons = [
    Icons.search_rounded,
    Icons.home_rounded,
    Icons.grid_view_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final onBg = ColoresApp.enSuperficie(isDark);
    final nav = AppLocalizations.of(context).nav;
    // La barra se mide con el aparato (en una tele de sillón crece el logo y
    // su renglón): `sobre` nunca encoge, así el escritorio se ve igual.
    final r = Responsive(context);
    final items = [
      for (var i = 0; i < _icons.length; i++)
        ItemLateral(_icons[i], nav.pestanas[i]),
    ];

    return SizedBox(
      width: anchoBarraLateral * r.factor,
      child: ContenedorVidrio(
        borderRadius: 0,
        blurSigma: 24,
        borderColor: onBg.withValues(alpha: 0.08),
        bgColor: ColoresApp.superficie(isDark).withValues(alpha: 0.72),
        padding: EdgeInsets.symmetric(
          vertical: r.sobre(24, 38),
          horizontal: r.spacingL,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo compacto arriba.
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: r.spacingM,
                vertical: r.spacingS,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.music_note_rounded,
                    color: onBg,
                    size: r.sobre(26, 38),
                  ),
                  SizedBox(width: r.spacingM),
                  Text(
                    'BITLY',
                    style: TextStyle(
                      color: onBg,
                      fontSize: r.sobre(18, 26),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.sobre(28, 42)),
            // Secciones de navegación (hover + indicador animado).
            ...List.generate(
              items.length,
              (i) => ItemLateralAnimado(
                item: items[i],
                seleccionado: currentIndex == i,
                onBg: onBg,
                onTap: () => onTap(i),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
