// ─────────────────────────────────────────────────────────────
// logo_pulsante.dart — Logo del splash con animación de pulso:
// círculo con glow (borde + sombra) cuyo brillo sigue la animación
// recibida, y el logo claro/oscuro según el tema. Centraliza el
// look del splash para la página de arranque.
// Se conecta con: features/splash (página) + tema (colores).
// Parte del flujo: splash (arranque de la app).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';

/// Logo con pulso y glow para la página de splash.
class LogoPulsante extends StatelessWidget {
  final Animation<double> pulse;
  final Responsive r;
  final bool isDark;

  const LogoPulsante({
    super.key,
    required this.pulse,
    required this.r,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
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
            color: ColoresApp.verdeOscuro.withValues(alpha: isDark ? 0.3 : 0.05),
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