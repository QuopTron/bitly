// ─────────────────────────────────────────────────────────────
// setup_escritorio.dart — Layout PC del setup: panel central de
// vidrio de ancho fijo (620px), indicador de pasos (puntos) en la
// parte superior y el slide actual dentro del panel con scroll. El
// slide de cada paso lo construye construir_paso (compartido con
// la variante móvil). Variante de escritorio del bienvenida.
// Se conecta con: setup_bloc (estado) + construir_paso (slides) +
// shared (vidrio, responsive, tema) + l10n.
// Parte del flujo: setup (bienvenida, variante escritorio).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../shared/widgets/base/comun/contenido_con_alto_minimo.dart';
import '../../../shared/widgets/vidrio/base/contenedor_vidrio.dart';
import '../bloc/base/setup_estado.dart';
import '../widgets/comunes/base/construir_paso.dart';
import '../widgets/comunes/base/indicador_pasos_setup.dart';

/// Variante de escritorio del flujo de setup.
class SetupEscritorio extends StatelessWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool esOscuro;
  final TextEditingController controladorUsuario;
  final void Function(String titulo, String mensaje) mostrarInfo;

  const SetupEscritorio({
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
    final onBg = esOscuro ? Colors.white : Colors.black;

    return Center(
      child: ContenedorVidrio(
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        padding: const EdgeInsets.all(28),
        borderRadius: 24,
        borderColor: onBg.withValues(alpha: 0.1),
        bgColor: onBg.withValues(alpha: 0.03),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // El indicador es compartido con las variantes de celular y TV
              // (ver indicador_pasos_setup): antes cada una tenía su copia.
              IndicadorPasosSetup(paso: state.paso, esOscuro: esOscuro),
              SizedBox(height: r.spacingL),
              // Sin SingleChildScrollView externo: los slides con Expanded/Spacer
              // (Google, carpeta, notificaciones) necesitan altura ACOTADA y
              // rompen dentro de un scroll infinito. Cada slide que lo necesita
              // (modo) trae su propio SingleChildScrollView interno.
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
                    // Garantiza el alto del slide (Spacer/Expanded lo exigen) y
                    // lo desplaza si la ventana quedó más baja que el mínimo,
                    // en vez de recortar el botón de continuar.
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
      ),
    );
  }
}
