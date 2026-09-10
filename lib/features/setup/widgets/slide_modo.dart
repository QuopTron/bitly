// ─────────────────────────────────────────────────────────────
// slide_modo.dart — Paso de modo de uso del setup: tarjetas Free/
// Premium con info, aviso de trial expirado, tarjeta de código
// premium (si eligió premium) y botones atrás/siguiente. Siguiente
// se habilita con modo elegido y código válido (en premium).
// Se conecta con: setup_bloc (SeleccionarModo, ValidarCodigoPremium,
// SiguientePaso, PasoAnterior) + shared (tarjeta modo, vidrio,
// botón) + tarjeta_codigo_premium + l10n.
// Parte del flujo: setup (paso 5: modo de uso).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/boton_vidrio.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';
import '../../../shared/widgets/tarjeta_modo.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_estado.dart';
import '../bloc/setup_evento.dart';
import 'tarjeta_codigo_premium.dart';

part 'slide_modo_widgets.dart';

/// Slide de selección de modo (free/premium).
class SlideModo extends StatelessWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;
  final void Function(String title, String message) showInfo;

  const SlideModo({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
    required this.showInfo,
  });

  @override
  Widget build(BuildContext context) {
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final trialExpirado = state.tieneDatosExistentes == true &&
        state.trialExistenteExpirado == true;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.only(bottom: r.bottomPadding + r.spacingS),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Spacer(),
                    SizedBox(height: r.spacingXL),
                    _icono(this, onBg),
                    SizedBox(height: r.spacingS),
                    Text(
                      loc.setup.chooseMode,
                      style: TextStyle(
                        fontSize: r.titleSize,
                        fontWeight: FontWeight.bold,
                        color: onBg,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: r.spacingM),
                    if (trialExpirado) _avisoTrial(this, onBg, glowColor),
                    _tarjetaFree(context, this, glowColor),
                    _tarjetaPremium(context, this, glowColor),
                    if (state.modoSeleccionado == 'premium')
                      TarjetaCodigoPremium(
                        state: state,
                        loc: loc,
                        r: r,
                        onBg: onBg,
                        glowColor: glowColor,
                      ),
                    const Spacer(),
                    _botones(context, this, glowColor),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

}