part of 'settings_sheet_new.dart';

/// Header del sheet de activación: ícono Premium brillante + título
/// + instrucción para ingresar el código.
class _PremiumSheetHeader extends StatelessWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _PremiumSheetHeader({
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor;

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [glow, glow.withValues(alpha: 0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        SizedBox(height: r.spacingM),
        Text(
          'Activar Premium',
          style: TextStyle(
            fontSize: r.titleSize,
            fontWeight: FontWeight.w800,
            color: onBg,
          ),
        ),
        SizedBox(height: r.spacingXS),
        Text(
          'Ingresa tu codigo para desbloquear descargas ilimitadas',
          style: TextStyle(
            fontSize: r.footerSize,
            color: onBg.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// Formulario del sheet de activación: input del código, error opcional
/// y botón Activar con estados de enviando/activado.
