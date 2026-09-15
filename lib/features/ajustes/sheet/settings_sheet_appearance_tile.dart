// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_tile.dart — PART de settings_sheet_new.dart: tile grande seleccionable (tema o
// estilo) con icono, etiqueta y estado resaltado.
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: Ajustes → Apariencia (tiles).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Un tile grande tappable del picker de tema (Oscuro / Claro):
/// ícono + etiqueta, resaltado cuando está seleccionado.
class _ThemeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(vertical: r.spacingL, horizontal: r.spacingM),
          decoration: BoxDecoration(
            gradient:
                selected
                    ? LinearGradient(
                      colors: [
                        glowColor.withValues(alpha: 0.18),
                        glowColor.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
            color: selected ? null : onBg.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected
                      ? glowColor.withValues(alpha: 0.45)
                      : onBg.withValues(alpha: 0.08),
              width: selected ? 1.5 : 1.0,
            ),
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ]
                    : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? glowColor : onBg.withValues(alpha: 0.45),
                size: r.subtitleSize + 10,
              ),
              SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: r.footerSize,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? glowColor : onBg.withValues(alpha: 0.55),
                  letterSpacing: selected ? 0.3 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
