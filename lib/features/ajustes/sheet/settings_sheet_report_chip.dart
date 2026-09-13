part of 'settings_sheet_new.dart';

/// Chip de selección Bug / Sugerencia dentro del diálogo de reporte.
class _ReportTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final Color onBg;
  final Color glow;
  final VoidCallback onTap;

  const _ReportTypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onBg,
    required this.glow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:
              selected
                  ? color.withValues(alpha: 0.18)
                  : onBg.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected
                    ? color.withValues(alpha: 0.6)
                    : onBg.withValues(alpha: 0.12),
            width: 1.4,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? color : onBg.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
