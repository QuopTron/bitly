// ─────────────────────────────────────────────────────────────
// slide_idioma.dart — Paso de idioma del setup: selección de
// Español/English con tarjetas, botón continuar que avanza al paso
// de usuario. Es el primer paso real del flujo (tras el chequeo de
// datos existentes).
// Se conecta con: setup_bloc (SeleccionarIdioma, SiguientePaso) +
// shared (tarjeta idioma, botón vidrio, responsive, tema) + l10n.
// Parte del flujo: setup (paso 2: idioma).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/boton_vidrio.dart';
import '../../../shared/widgets/tarjeta_idioma.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_estado.dart';
import '../bloc/setup_evento.dart';

/// Slide de selección de idioma.
class SlideIdioma extends StatelessWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const SlideIdioma({
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
      key: const ValueKey('language'),
      padding: EdgeInsets.only(bottom: r.bottomPadding),
      child: Column(
        children: [
          const Spacer(),
          _icono(onBg),
          SizedBox(height: r.spacingS),
          Text(
            loc.setup.selectLanguage,
            style: TextStyle(
              fontSize: r.titleSize,
              fontWeight: FontWeight.bold,
              color: onBg,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 2),
          Text(
            loc.setup.chooseLanguage,
            style: TextStyle(
              fontSize: r.footerSize,
              color: onBg.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: r.spacingL),
          TarjetaIdioma(
            icon: Icons.language,
            iconColor: ColoresApp.verdeBrillante,
            name: loc.setup.espanol,
            selected: state.idiomaSeleccionado == 'es',
            onTap: () => context
                .read<SetupBloc>()
                .add(const SeleccionarIdioma('es')),
            glowColor: glowColor,
          ),
          TarjetaIdioma(
            icon: Icons.language,
            iconColor: ColoresApp.primario,
            name: loc.setup.english,
            selected: state.idiomaSeleccionado == 'en',
            onTap: () => context
                .read<SetupBloc>()
                .add(const SeleccionarIdioma('en')),
            glowColor: glowColor,
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
            child: BotonVidrio(
              label: loc.setup.continueText,
              onPressed: () =>
                  context.read<SetupBloc>().add(const SiguientePaso()),
              height: r.continueButtonHeight,
              accent: glowColor,
            ),
          ),
          SizedBox(height: r.spacingS),
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
        Icons.language,
        size: r.titleSize * 1.1,
        color: onBg.withValues(alpha: 0.55),
      ),
    );
  }
}