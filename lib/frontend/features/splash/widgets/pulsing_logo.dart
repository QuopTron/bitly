import 'package:flutter/material.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/theme/app_colors.dart';

class PulsingLogo extends StatelessWidget {
  final Animation<double> pulse;
  final Responsive r;
  final bool isDark;

  const PulsingLogo({
    super.key,
    required this.pulse,
    required this.r,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor =
        isDark ? AppColors.greenBright : AppColors.greenMedium;
    final logo = isDark
        ? 'assets/images/logoBitlyOscuro.png'
        : 'assets/images/logoBitlyClaro.png';

    return AnimatedBuilder(
      animation: pulse,
      child: Image.asset(logo, height: r.logoSize, fit: BoxFit.contain),
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(r.circlePadding),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.darkGreen.withValues(alpha: isDark ? 0.3 : 0.05),
            border: Border.all(
              color: glowColor.withValues(alpha: pulse.value * 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: pulse.value * 0.25),
                blurRadius: 12 * pulse.value,
                spreadRadius: 3 * pulse.value,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}


