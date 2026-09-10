// ─────────────────────────────────────────────────────────────
// splash_movil.dart — Variante MÓVIL del splash (celular/tablet
// vertical): fondo de partículas a pantalla completa, logo pulsante
// centrado, título BITLY y panel de error con reintentar si el
// backend no responde. Es el diseño original de la app.
// Se conecta con: pagina_splash (selector) + shared (fondo,
// logo, panel de error, responsive, tema) + l10n.
// Parte del flujo: arranque (variante móvil).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/fondo_particulas.dart';
import 'bloc/splash_estado.dart';
import 'widgets/logo_pulsante.dart';
import 'widgets/panel_error.dart';

/// Splash móvil: logo centrado a pantalla completa.
class SplashMovil extends StatelessWidget {
  final EstadoSplash estado;
  final Animation<double> pulse;

  const SplashMovil({
    super.key,
    required this.estado,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? ColoresApp.fondoOscuro : ColoresApp.fondoClaro;
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          FondoParticulas(
            glowColor: glowColor,
            particleColor: onBg,
            particleCount: 10,
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LogoPulsante(pulse: pulse, r: r, isDark: isDark),
                  SizedBox(height: r.spacingL),
                  Text(
                    'BITLY',
                    style: TextStyle(
                      fontSize: r.titleSize,
                      fontWeight: FontWeight.bold,
                      color: onBg,
                      letterSpacing: 8,
                    ),
                  ),
                  if (estado.status == EstatusSplash.error)
                    PanelError(state: estado, loc: loc, r: r, isDark: isDark),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: r.bottomPadding,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'POWERED BY FLOX',
                style: TextStyle(
                  fontSize: r.footerSize,
                  color: onBg.withValues(alpha: 0.4),
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}