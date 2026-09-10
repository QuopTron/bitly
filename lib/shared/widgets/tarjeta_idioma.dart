// ─────────────────────────────────────────────────────────────
// tarjeta_idioma.dart — Tarjeta de selección de idioma del setup:
// icono, nombre y estado seleccionado con animación y check. Se
// usa en el paso de idioma para elegir Español/English.
// Se conecta con: features/setup (slide de idioma) + responsive.
// Parte del flujo: setup (paso de idioma).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../utilidades/responsive.dart';

/// Tarjeta de idioma seleccionable.
class TarjetaIdioma extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final Color glowColor;

  const TarjetaIdioma({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.selected,
    required this.onTap,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.languageCardMargin,
          vertical: r.spacingXS,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: r.spacingM,
            horizontal: r.spacingL,
          ),
          decoration: BoxDecoration(
            color: selected
                ? glowColor.withValues(alpha: 0.1)
                : onBg.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? glowColor.withValues(alpha: 0.5)
                  : onBg.withValues(alpha: 0.06),
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            children: [
              _iconBox(r),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: r.subtitleSize,
                    color: selected ? onBg : onBg.withValues(alpha: 0.65),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  color: glowColor,
                  size: r.languageCheckSize + 2,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(Responsive r) {
    return Container(
      width: r.languageCardIconSize,
      height: r.languageCardIconSize,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: r.languageCardIconSize * 0.5),
    );
  }
}