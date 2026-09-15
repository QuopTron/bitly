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

import '../../../shared/tema/colores_app.dart';
import '../../../shared/widgets/vidrio/contenedor_vidrio.dart';
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

  static const _items = [
    ItemLateral(Icons.search_rounded, 'Buscar'),
    ItemLateral(Icons.home_rounded, 'Inicio'),
    ItemLateral(Icons.grid_view_rounded, 'Mi Espacio'),
  ];

  @override
  Widget build(BuildContext context) {
    final onBg = ColoresApp.enSuperficie(isDark);

    return SizedBox(
      width: anchoBarraLateral,
      child: ContenedorVidrio(
        borderRadius: 0,
        blurSigma: 24,
        borderColor: onBg.withValues(alpha: 0.08),
        bgColor: ColoresApp.superficie(isDark).withValues(alpha: 0.72),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo compacto arriba.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.music_note_rounded, color: onBg, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'BITLY',
                    style: TextStyle(
                      color: onBg,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Secciones de navegación (hover + indicador animado).
            ...List.generate(
              _items.length,
              (i) =>              ItemLateralAnimado(
                item: _items[i],
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

