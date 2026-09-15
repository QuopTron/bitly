// ─────────────────────────────────────────────────────────────
// barra_lateral_item.dart — Ítem animado de la barra lateral
// de escritorio: fondo con hover, icono con escala, indicador
// de selección con barra lateral animada.
//
// Se conecta con: barra_navegacion_lateral.dart (lo monta).
// Parte del flujo: Home → navegación de secciones en escritorio.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Modelo de ítem de la barra lateral.
class ItemLateral {
  final IconData icon;
  final String label;
  const ItemLateral(this.icon, this.label);
}

/// Ítem de la barra lateral con hover animado (solo escritorio).
class ItemLateralAnimado extends StatefulWidget {
  final ItemLateral item;
  final bool seleccionado;
  final Color onBg;
  final VoidCallback onTap;

  const ItemLateralAnimado({
    super.key,
    required this.item,
    required this.seleccionado,
    required this.onBg,
    required this.onTap,
  });

  @override
  State<ItemLateralAnimado> createState() => _ItemLateralAnimadoState();
}

class _ItemLateralAnimadoState extends State<ItemLateralAnimado> {
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
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
                    AnimatedScale(
                      scale: _hover ? 1.12 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Icon(
                        widget.item.icon,
                        size: 22,
                        color: sel ? onBg : onBg.withValues(alpha: _hover ? 0.75 : 0.4),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        style: TextStyle(
                          color: sel ? onBg : onBg.withValues(alpha: _hover ? 0.8 : 0.55),
                          fontSize: 14,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                        child: Text(widget.item.label),
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: sel ? 1 : 0,
                      child: Container(
                        width: 4, height: 4,
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
