part of 'settings_sheet_new.dart';

/// Chip con el tiempo restante de prueba gratis (o EXPIRADO).
/// Solo se muestra cuando el usuario free tiene una prueba registrada.
class _TrialChip extends StatelessWidget {
  final String trialRemaining;
  final Color glowColor;
  final Responsive r;

  const _TrialChip({
    required this.trialRemaining,
    required this.glowColor,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final expired = trialRemaining == 'EXPIRADO';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:
            expired
                ? Colors.redAccent.withValues(alpha: 0.2)
                : glowColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        trialRemaining,
        style: TextStyle(
          fontSize: r.footerSize - 2,
          color: expired ? Colors.redAccent : glowColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
