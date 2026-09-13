part of 'settings_sheet_new.dart';

/// Toggle Bug / Sugerencia del diálogo de reporte: dos chips seleccionables
/// que actualizan el tipo del reporte a crear.
class _ReportTypeToggle extends StatelessWidget {
  final bool isBug;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final void Function(bool) onChanged;

  const _ReportTypeToggle({
    required this.isBug,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final glow = glowColor;

    return Row(
      children: [
        Expanded(
          child: _ReportTypeChip(
            label: loc.setup.reportTypeBug,
            selected: isBug,
            color: Colors.redAccent,
            onBg: onBg,
            glow: glow,
            onTap: () => onChanged(true),
          ),
        ),
        SizedBox(width: r.spacingS),
        Expanded(
          child: _ReportTypeChip(
            label: loc.setup.reportTypeSuggestion,
            selected: !isBug,
            color: Colors.amber,
            onBg: onBg,
            glow: glow,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}
