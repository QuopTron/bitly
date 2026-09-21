// ─────────────────────────────────────────────────────────────
// settings_sheet_nav_riel_item.dart — PART de settings_sheet_new.dart:
// una fila del riel lateral de Ajustes.
//
// Ícono en recuadro + nombre completo; la pestaña activa lleva el degradado
// del acento, el halo y una barrita a la derecha, para ubicarse de un
// vistazo sin leer todo el menú.
//
// Se conecta con: settings_sheet_nav_riel.dart (lo usa) y
// settings_sheet_entry.dart (de dónde sale el ícono).
// Parte del flujo: Ajustes → navegación (pantalla ancha).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Una fila del riel: ícono en recuadro + nombre.
class _RielItem extends StatelessWidget {
  final int index;
  final String etiqueta;
  final bool active;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onTap;

  const _RielItem({
    required this.index,
    required this.etiqueta,
    required this.active,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.symmetric(vertical: r.spacingXS / 3),
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingS,
          vertical: r.spacingXS / 1.5,
        ),
        decoration: BoxDecoration(
          gradient:
              active
                  ? LinearGradient(
                    colors: [
                      glowColor.withValues(alpha: 0.85),
                      glowColor.withValues(alpha: 0.45),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                  : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow:
              active
                  ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.28),
                      blurRadius: 14,
                    ),
                  ]
                  : null,
        ),
        child: Row(
          children: [
            Icon(
              _iconosPestanas[index],
              size: r.subtitleSize,
              color: active ? Colors.white : onBg.withValues(alpha: 0.55),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.footerSize,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : onBg.withValues(alpha: 0.6),
                  letterSpacing: active ? 0.2 : 0,
                ),
              ),
            ),
            // Barrita de la pestaña activa, para ubicarse de un vistazo.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: active ? 3 : 0,
              height: r.subtitleSize,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
