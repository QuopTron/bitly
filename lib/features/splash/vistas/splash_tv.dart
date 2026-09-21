// ─────────────────────────────────────────────────────────────
// splash_tv.dart — Variante TV del splash: el mismo logo pulsante, el título
// BITLY y el panel de error, dentro del panel PLANO de TV y con el texto más
// grande (se mira a metros).
//
// Diferencia de peso a propósito: la tele NO monta las partículas de fondo.
// En PC son 12 partículas animadas en pantalla completa y en una GPU de TV se
// recompone cada frame sin que a tres metros se note; el fondo plano del
// lienzo ya se ve bien.
//
// Se conecta con: pagina_splash (selector) + panel_tv + logo_pulsante +
// panel_error + l10n.
// Parte del flujo: arranque (variante TV).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../shared/widgets/paneles/panel_tv.dart';
import '../bloc/splash_estado.dart';
import '../widgets/logo_pulsante.dart';
import '../widgets/panel_error.dart';

/// Ancho máximo del panel central en TV.
const double _anchoMaximoPanelTv = 720;

/// Splash de TV: panel plano centrado, logo y título más grandes.
class SplashTv extends StatelessWidget {
  final EstadoSplash estado;
  final Animation<double> pulse;

  const SplashTv({super.key, required this.estado, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? ColoresApp.fondoOscuro : ColoresApp.fondoClaro;
    final onBg = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: PanelTv(
                anchoMaximo: _anchoMaximoPanelTv,
                padding: const EdgeInsets.symmetric(
                  horizontal: 56,
                  vertical: 48,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LogoPulsante(pulse: pulse, r: r, isDark: isDark),
                    const SizedBox(height: 20),
                    Text(
                      'BITLY',
                      style: TextStyle(
                        // Más grande que en PC: a metros se lee de lejos.
                        fontSize: r.titleSize + 12,
                        fontWeight: FontWeight.bold,
                        color: onBg,
                        letterSpacing: 10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loc.splash.lema,
                      style: TextStyle(
                        fontSize: r.subtitleSize + 2,
                        color: onBg.withValues(alpha: 0.5),
                      ),
                    ),
                    if (estado.status == EstatusSplash.error) ...[
                      const SizedBox(height: 10),
                      PanelError(state: estado, loc: loc, r: r, isDark: isDark),
                    ],
                  ],
                ),
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
