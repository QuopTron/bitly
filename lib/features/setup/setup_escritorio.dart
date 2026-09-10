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

import '../../l10n/app_localizations.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/contenedor_vidrio.dart';
import 'bloc/setup_estado.dart';
import 'widgets/construir_paso.dart';

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

  static const _pasosVisibles = 7;

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
              _indicadorPasos(onBg),
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
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: SizedBox(
                    key: ValueKey(state.paso),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _indicadorPasos(Color onBg) {
    final indice = _indicePaso(state.paso);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _pasosVisibles; i++)
          Container(
            width: i == indice ? 22 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i <= indice
                  ? (esOscuro
                      ? ColoresApp.verdeBrillante
                      : ColoresApp.verdeMedio)
                  : onBg.withValues(alpha: 0.15),
            ),
          ),
      ],
    );
  }

  int _indicePaso(PasoSetup paso) {
    switch (paso) {
      case PasoSetup.promptReingreso:
      case PasoSetup.idioma:
      case PasoSetup.chequeandoExistente:
        return 0;
      case PasoSetup.usuario:
        return 1;
      case PasoSetup.googleSignIn:
        return 2;
      case PasoSetup.modo:
        return 3;
      case PasoSetup.carpetaAlmacenamiento:
        return 4;
      case PasoSetup.notificaciones:
        return 5;
      case PasoSetup.verificacion:
      case PasoSetup.gracias:
        return 6;
    }
  }
}