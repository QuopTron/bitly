part of 'settings_sheet_new.dart';

/// Card de cuenta Premium dentro del tab "Más" del settings sheet.
/// Muestra el tier real (Free/Premium) y, para usuarios free, permite
/// activar un código premium desde una bottom-sheet.
class _PremiumCardWidget extends StatelessWidget {
  final Color glowColor;
  final EstadoPremium? premium;
  final String? trialRemaining;
  final Future<void> Function() onPremiumChanged;

  const _PremiumCardWidget({
    required this.glowColor,
    required this.premium,
    required this.trialRemaining,
    required this.onPremiumChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final isPremium = premium?.esPremium ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isPremium
                  ? Icons.workspace_premium_rounded
                  : Icons.person_outline_rounded,
              color: glowColor,
              size: r.subtitleSize,
            ),
            SizedBox(width: r.spacingS),
            Text(
              'Cuenta',
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w700,
                color: onBg,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          isPremium
              ? 'Tienes Premium: descargas ilimitadas para siempre.'
              : 'Modo Free: acceso a descargas gratis por 8 horas desde tu primera activacion.',
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.5),
            height: 1.3,
          ),
        ),
        SizedBox(height: r.spacingS),
        _PremiumActivationCard(
          isPremium: isPremium,
          trialRemaining: trialRemaining,
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          onPremiumChanged: onPremiumChanged,
        ),
      ],
    );
  }
}

/// Card tappable de activación: muestra Free/Premium con el trial restante
/// y abre la bottom-sheet de activación de código al tocarla.
