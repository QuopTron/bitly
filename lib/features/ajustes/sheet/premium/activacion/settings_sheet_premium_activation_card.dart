// ─────────────────────────────────────────────────────────────
// settings_sheet_premium_activation_card.dart — PART de settings_sheet_new.dart: tarjeta que invita a activar
// Premium cuando la prueba gratis terminó.
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: Ajustes → Más (activación Premium).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

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
    final t = AppLocalizations.of(context).ajustes;
    final expirado = trialRemaining == 'EXPIRADO';

    return GestureDetector(
      // `sobreHoja`: la activación se abre desde dentro de Ajustes y tapa la
      // hoja de abajo (si no, se veían dos modales).
      onTap:
          isPremium
              ? null
              : () => mostrarHoja<void>(
                context: context,
                sobreHoja: true,
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
                        isPremium ? t.premiumActivo : t.planFree,
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
                                expirado
                                    ? Colors.redAccent.withValues(alpha: 0.2)
                                    : glowColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            expirado ? t.trialExpirado : trialRemaining!,
                            style: TextStyle(
                              fontSize: r.footerSize - 3,
                              color: expirado ? Colors.redAccent : glowColor,
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
                        ? t.premiumBeneficios
                        : (expirado
                            ? t.premiumActivarExpirado
                            : t.premiumActivar),
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
