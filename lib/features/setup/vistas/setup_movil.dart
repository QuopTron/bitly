// ─────────────────────────────────────────────────────────────
// setup_movil.dart — Layout CELULAR del setup: ancho máximo de
// 560px centrado y AnimatedSwitcher con fundido entre pasos. El
// slide de cada paso lo construye construir_paso (compartido con
// la variante escritorio). Es el diseño Android actual.
// Se conecta con: setup_bloc (estado) + construir_paso (slides) +
// shared (responsive) + l10n.
// Parte del flujo: setup (bienvenida, variante móvil).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../shared/widgets/base/contenido_con_alto_minimo.dart';
import '../bloc/setup_estado.dart';
import '../widgets/comunes/construir_paso.dart';

/// Variante móvil del flujo de setup.
class SetupMovil extends StatelessWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool esOscuro;
  final TextEditingController controladorUsuario;
  final void Function(String titulo, String mensaje) mostrarInfo;

  const SetupMovil({
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
    return Padding(
      padding: EdgeInsets.only(top: r.topPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final anchoMax =
              constraints.maxWidth > 600 ? 560.0 : constraints.maxWidth;
          return Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: SizedBox(
                key: ValueKey(state.paso),
                width: anchoMax,
                // Los slides usan Spacer/Expanded, que exigen alto acotado. Con
                // una pantalla baja (o el "tamaño de fuente"/"tamaño de
                // pantalla" del sistema subidos) el contenido no entraba, el
                // slide desbordaba y el botón de continuar quedaba fuera de
                // alcance. Acá se garantiza el alto y se desplaza si hace falta.
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
          );
        },
      ),
    );
  }
}