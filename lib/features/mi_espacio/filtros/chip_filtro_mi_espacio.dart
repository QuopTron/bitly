// ─────────────────────────────────────────────────────────────
// chip_filtro_mi_espacio.dart — Chip compacto (ícono + etiqueta) de
// filtro/orden de Mi Espacio; se ilumina al estar activo.
// Se conecta con: controles_orden_mi_espacio + responsive.
// Parte del flujo: Home → Mi Espacio (chip de filtro).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/utilidades/plataforma/responsive.dart';

/// Chip compacto (ícono + etiqueta) que se ilumina al estar activo.
class ChipFiltroMiEspacio extends StatelessWidget {
  final Responsive r;
  final Color onBg;
  final IconData icon;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const ChipFiltroMiEspacio({
    super.key,
    required this.r,
    required this.onBg,
    required this.icon,
    required this.label,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = activo
        ? onBg.withValues(alpha: 0.8)
        : onBg.withValues(alpha: 0.35);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingS,
          vertical: r.spacingXS,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: onBg.withValues(alpha: activo ? 0.12 : 0.04),
          border: Border.all(
            color: onBg.withValues(alpha: activo ? 0.3 : 0.08),
            width: activo ? 0.8 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: r.footerSize + 1, color: color),
            SizedBox(width: r.spacingXS),
            Text(
              label,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
