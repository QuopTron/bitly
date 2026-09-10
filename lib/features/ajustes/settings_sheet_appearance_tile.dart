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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: r.spacingM),
        decoration: BoxDecoration(
          color:
              selected
                  ? glowColor.withValues(alpha: 0.16)
                  : onBg.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected
                    ? glowColor.withValues(alpha: 0.5)
                    : onBg.withValues(alpha: 0.1),
            width: 1.4,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? glowColor : onBg.withValues(alpha: 0.5),
              size: r.subtitleSize + 4,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: r.footerSize,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? glowColor : onBg.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
