// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_toggle.dart — PART de settings_sheet_new.dart: toggle individual (ícono + label + descripción + switch) de un componente visual del estilo Spotify.
// Se conecta con: settings_sheet_new.dart (misma library) + settings_sheet_appearance_granular.
// Parte del flujo: Ajustes → Apariencia (toggle de componente).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

// Toggle individual para un componente visual.
class _ToggleGranular extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final ValueChanged<bool> onChanged;

  const _ToggleGranular({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.spacingXS),
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: r.spacingM,
            vertical: r.spacingS + 2,
          ),
          decoration: BoxDecoration(
            color: value
                ? glowColor.withValues(alpha: 0.08)
                : onBg.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value
                  ? glowColor.withValues(alpha: 0.25)
                  : onBg.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: r.footerSize + 8,
                color: value ? glowColor : onBg.withValues(alpha: 0.4),
              ),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: r.footerSize + 1,
                        fontWeight: FontWeight.w600,
                        color: value ? onBg : onBg.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: r.footerSize - 2,
                        color: onBg.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  value
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  key: ValueKey(value),
                  size: 32,
                  color: value ? glowColor : onBg.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
