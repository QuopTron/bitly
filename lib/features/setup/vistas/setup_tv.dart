// ─────────────────────────────────────────────────────────────
// setup_tv.dart — Variante TV del setup: el mismo flujo de bienvenida en un
// panel PLANO, más ancho y con el indicador de pasos separado (se ve de
// lejos), sin vidrio ni desenfoque.
//
// El paso actual lo construye construirPasoSetup, compartido con las otras
// variantes: acá no hay lógica duplicada, solo la forma de presentarla en una
// tele (donde se navega con el control remoto y hay más ancho para respirar).
//
// Se conecta con: setup_bloc (estado) + construir_paso (slides) + panel_tv +
// indicador_pasos_setup + l10n.
// Parte del flujo: setup (bienvenida, variante TV).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../shared/widgets/base/comun/contenido_con_alto_minimo.dart';
import '../../../shared/widgets/paneles/panel_tv.dart';
import '../bloc/base/setup_estado.dart';
import '../widgets/comunes/base/construir_paso.dart';
import '../widgets/comunes/base/indicador_pasos_setup.dart';

/// Variante de TV del flujo de setup.
class SetupTv extends StatelessWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool esOscuro;
  final TextEditingController controladorUsuario;
  final void Function(String titulo, String mensaje) mostrarInfo;

  const SetupTv({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.esOscuro,
    required this.controladorUsuario,
    required this.mostrarInfo,
  });

  @override
  Widget build(BuildContext context) {
    return PanelTv(
      anchoMaximo: 1000,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sin `separacion` propia: el indicador ya escala por aparato.
            IndicadorPasosSetup(paso: state.paso, esOscuro: esOscuro),
            SizedBox(height: r.spacingL * 1.2),
            // Sin SingleChildScrollView externo: los slides con Expanded/Spacer
            // necesitan altura ACOTADA y rompen dentro de un scroll infinito.
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder:
                    (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                child: SizedBox(
                  key: ValueKey(state.paso),
                  child: ContenidoConAltoMinimo(
                    altoMinimo: altoMinimoSlideSetup,
                    child: construirPasoSetup(
                      state,
                      loc,
                      r,
                      esOscuro,
                      controladorUsuario,
                      mostrarInfo,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
