// Parte del split de settings_sheet_new.dart — widgets de _ProfileStatsView.
// Extraídos del build original (ver git log). No editar a mano.
part of 'settings_sheet_new.dart';

/// Banner superior de estadísticas: Premium o Free (con trial restante).
class _StatsTierBanner extends StatelessWidget {
  final bool isPremium;
  final String? trialRemaining;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final AppLocalizations loc;

  const _StatsTierBanner({
    required this.isPremium,
    required this.trialRemaining,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor;
    if (isPremium) {
      return Container(
        margin: EdgeInsets.only(bottom: r.spacingM),
        padding: EdgeInsets.all(r.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              glow.withValues(alpha: 0.20),
              glow.withValues(alpha: 0.07),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: glow.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: glow,
              size: r.subtitleSize,
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.setup.premium,
                    style: TextStyle(
                      fontSize: r.subtitleSize - 1,
                      fontWeight: FontWeight.w700,
                      color: glow,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    loc.setup.premiumInfo,
                    style: TextStyle(
                      fontSize: r.footerSize,
                      color: onBg.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final expired = trialRemaining == 'EXPIRADO';
    return Container(
      margin: EdgeInsets.only(bottom: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [glow.withValues(alpha: 0.16), glow.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: glow.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            expired ? Icons.timer_off_rounded : Icons.timer_rounded,
            color: expired ? Colors.redAccent : glow,
            size: r.subtitleSize,
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Free',
                      style: TextStyle(
                        fontSize: r.subtitleSize - 1,
                        fontWeight: FontWeight.w700,
                        color: glow,
                      ),
                    ),
                    if (trialRemaining != null) ...[
                      SizedBox(width: r.spacingS),
                      _TrialChip(
                        trialRemaining: trialRemaining!,
                        glowColor: glow,
                        r: r,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  expired
                      ? 'Tu periodo de descarga gratis ha expirado. Activa Premium para descargar ilimitado.'
                      : loc.setup.freeInfo,
                  style: TextStyle(
                    fontSize: r.footerSize,
                    color: onBg.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
