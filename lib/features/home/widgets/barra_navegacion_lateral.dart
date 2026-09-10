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
import '../../../shared/widgets/contenedor_vidrio.dart';

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
    _ItemLateral(Icons.search_rounded, 'Buscar'),
    _ItemLateral(Icons.home_rounded, 'Inicio'),
    _ItemLateral(Icons.grid_view_rounded, 'Mi Espacio'),
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
              (i) => _ItemLateralAnimado(
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

/// Ítem de la barra lateral con hover (solo escritorio): el fondo aparece con
/// animación al pasar el mouse, el icono escala suavemente y la selección
/// muestra una barra lateral + punto. La barra se estira con AnimatedContainer
/// para dar el efecto de indicador que "se enciende".
class _ItemLateralAnimado extends StatefulWidget {
  final _ItemLateral item;
  final bool seleccionado;
  final Color onBg;
  final VoidCallback onTap;

  const _ItemLateralAnimado({
    required this.item,
    required this.seleccionado,
    required this.onBg,
    required this.onTap,
  });

  @override
  State<_ItemLateralAnimado> createState() => _ItemLateralAnimadoState();
}

class _ItemLateralAnimadoState extends State<_ItemLateralAnimado> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.seleccionado;
    final onBg = widget.onBg;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: sel
                    ? onBg.withValues(alpha: 0.12)
                    : _hover
                        ? onBg.withValues(alpha: 0.06)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Barra indicadora de selección (se estira al activarse).
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      width: sel ? 3 : 0,
                      height: 18,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: onBg.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Icono con escala sutil al hover.
                    AnimatedScale(
                      scale: _hover ? 1.12 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Icon(
                        widget.item.icon,
                        size: 22,
                        color:
                            sel ? onBg : onBg.withValues(alpha: _hover ? 0.75 : 0.4),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        style: TextStyle(
                          color: sel
                              ? onBg
                              : onBg.withValues(alpha: _hover ? 0.8 : 0.55),
                          fontSize: 14,
                          fontWeight:
                              sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                        child: Text(widget.item.label),
                      ),
                    ),
                    // Punto de selección al final.
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: sel ? 1 : 0,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: onBg.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemLateral {
  final IconData icon;
  final String label;
  const _ItemLateral(this.icon, this.label);
}