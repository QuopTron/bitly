// ─────────────────────────────────────────────────────────────
// prompt_reingreso.dart — Paso "¿Continuar con tu cuenta?" del
// setup: aparece cuando hay un setup completado previo. Muestra el
// resumen de la cuenta existente y botones Sí (continuar) / No
// (empezar de nuevo). Al decir No se conservan los datos y se
// editan desde el paso de idioma.
// Se conecta con: setup_bloc (AceptarDatosExistentes) +
// tarjeta_info_cuenta + shared (botón vidrio, responsive, tema).
// Parte del flujo: setup (paso 1: reingreso).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/boton_vidrio.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_estado.dart';
import '../bloc/setup_evento.dart';
import 'tarjeta_info_cuenta.dart';

/// Prompt de reingreso con cuenta existente.
class PromptReingreso extends StatelessWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const PromptReingreso({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: Column(
        children: [
          const Spacer(),
          _icono(onBg),
          SizedBox(height: r.spacingS),
          Text(
            loc.setup.existingAccount,
            style: TextStyle(
              fontSize: r.titleSize,
              fontWeight: FontWeight.bold,
              color: onBg,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: r.spacingS),
          Text(
            loc.setup.returningUser,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.footerSize,
              color: onBg.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: r.spacingM),
          TarjetaInfoCuenta(
            state: state,
            loc: loc,
            r: r,
            onBg: onBg,
            glowColor: glowColor,
          ),
          SizedBox(height: r.spacingM),
          Text(
            loc.setup.startFresh,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.footerSize - 1,
              color: onBg.withValues(alpha: 0.4),
            ),
          ),
          const Spacer(),
          BotonVidrio(
            label: loc.setup.yes,
            onPressed: () => context
                .read<SetupBloc>()
                .add(const AceptarDatosExistentes(true)),
            height: r.continueButtonHeight,
            accent: glowColor,
          ),
          SizedBox(height: r.spacingM),
          BotonVidrio(
            label: loc.setup.no,
            onPressed: () => context
                .read<SetupBloc>()
                .add(const AceptarDatosExistentes(false)),
            height: r.continueButtonHeight,
            accent: glowColor,
          ),
          SizedBox(height: r.spacingM),
        ],
      ),
    );
  }

  Widget _icono(Color onBg) {
    return Container(
      padding: EdgeInsets.all(r.spacingS),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onBg.withValues(alpha: 0.04),
        border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
      ),
      child: Icon(
        Icons.person_outline,
        size: r.titleSize * 1.5,
        color: onBg.withValues(alpha: 0.55),
      ),
    );
  }
}