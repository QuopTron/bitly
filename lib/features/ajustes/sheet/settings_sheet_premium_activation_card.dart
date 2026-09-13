part of 'settings_sheet_new.dart';

class _PremiumActivationCard extends StatelessWidget {
  final bool isPremium;
  final String? trialRemaining;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final Future<void> Function() onPremiumChanged;

  const _PremiumActivationCard({
    required this.isPremium,
    required this.trialRemaining,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onPremiumChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          isPremium
              ? null
              : () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder:
                    (_) => _PremiumActivationSheet(
                      glowColor: glowColor,
                      onPremiumChanged: onPremiumChanged,
                    ),
              ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(r.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isPremium
                    ? [
                      glowColor.withValues(alpha: 0.16),
                      glowColor.withValues(alpha: 0.05),
                    ]
                    : [
                      glowColor.withValues(alpha: 0.10),
                      onBg.withValues(alpha: 0.02),
                    ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: glowColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              isPremium
                  ? Icons.check_circle_rounded
                  : Icons.workspace_premium_rounded,
              color: glowColor,
              size: r.footerSize + 4,
            ),
            SizedBox(width: r.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isPremium ? 'Premium activo' : 'Free',
                        style: TextStyle(
                          fontSize: r.subtitleSize - 1,
                          fontWeight: FontWeight.w600,
                          color: isPremium ? glowColor : onBg,
                        ),
                      ),
                      if (!isPremium && trialRemaining != null) ...[
                        SizedBox(width: r.spacingS),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                trialRemaining == 'EXPIRADO'
                                    ? Colors.redAccent.withValues(alpha: 0.2)
                                    : glowColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trialRemaining!,
                            style: TextStyle(
                              fontSize: r.footerSize - 3,
                              color:
                                  trialRemaining == 'EXPIRADO'
                                      ? Colors.redAccent
                                      : glowColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    isPremium
                        ? 'Cuenta con todos los beneficios'
                        : (trialRemaining == 'EXPIRADO'
                            ? 'Activa Premium para descargar ilimitado'
                            : 'Toca para activar un codigo premium'),
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: onBg.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (!isPremium)
              Icon(
                Icons.chevron_right_rounded,
                color: glowColor,
                size: r.subtitleSize,
              ),
          ],
        ),
      ),
    );
  }
}
