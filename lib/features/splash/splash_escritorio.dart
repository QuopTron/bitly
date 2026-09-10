// ─────────────────────────────────────────────────────────────
// splash_escritorio.dart — Variante de ESCRITORIO del splash
// (PC/web/pantallas anchas): conserva el logo pulsante, el título
// BITLY y el panel de error, pero los presenta dentro de un panel
// de vidrio centrado con ancho máximo y un layout horizontal
// (logo a la izquierda, textos a la derecha), aprovechando la
// pantalla ancha en vez de estirar el diseño móvil.
// Se conecta con: pagina_splash (selector) + shared (vidrio,
// fondo, logo, panel de error, responsive, tema) + l10n.
// Parte del flujo: arranque (variante escritorio).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/contenedor_vidrio.dart';
import '../../shared/widgets/fondo_particulas.dart';
import 'bloc/splash_estado.dart';
import 'widgets/logo_pulsante.dart';
import 'widgets/panel_error.dart';

/// Ancho máximo del panel central en escritorio.
const double _anchoMaximoPanel = 560;

/// Splash de escritorio: panel de vidrio centrado con layout horizontal.
class SplashEscritorio extends StatelessWidget {
  final EstadoSplash estado;
  final Animation<double> pulse;

  const SplashEscritorio({
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
            particleCount: 12,
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _anchoMaximoPanel),
                child: ContenedorVidrio(
                  blurSigma: 24,
                  borderColor: onBg.withValues(alpha: 0.12),
                  bgColor: ColoresApp.superficie(isDark).withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 36,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo + textos en horizontal, aprovechando el ancho.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LogoPulsante(pulse: pulse, r: r, isDark: isDark),
                          const SizedBox(width: 32),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'BITLY',
                                  style: TextStyle(
                                    fontSize: r.titleSize + 6,
                                    fontWeight: FontWeight.bold,
                                    color: onBg,
                                    letterSpacing: 8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tu música, todas tus fuentes.',
                                  style: TextStyle(
                                    fontSize: r.subtitleSize,
                                    color: onBg.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (estado.status == EstatusSplash.error) ...[
                        const SizedBox(height: 8),
                        PanelError(
                          state: estado,
                          loc: loc,
                          r: r,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
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