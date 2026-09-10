// ─────────────────────────────────────────────────────────────
// slide_usuario.dart — Paso de nombre de usuario del setup:
// ícono, título, banner de nombre previo (cuando hay cuenta
// existente), campo de texto con generador aleatorio y botones
// atrás/siguiente (siguiente se habilita con texto no vacío).
// Se conecta con: setup_bloc (UsuarioCambiado, SiguientePaso,
// PasoAnterior) + campo_usuario + shared + l10n.
// Parte del flujo: setup (paso 3: nombre de usuario).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/boton_vidrio.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_estado.dart';
import '../bloc/setup_evento.dart';
import 'campo_usuario.dart';

part 'slide_usuario_widgets.dart';

/// Slide del nombre de usuario.
class SlideUsuario extends StatelessWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;
  final TextEditingController controller;

  const SlideUsuario({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final tieneExistente = state.tieneDatosExistentes == true &&
        state.continuarConExistentes == false &&
        (state.usuarioExistente ?? '').isNotEmpty;

    return Padding(
      key: const ValueKey('username'),
      padding: EdgeInsets.only(bottom: r.bottomPadding),
      child: Column(
        children: [
          const Spacer(),
          _icono(this, onBg),
          SizedBox(height: r.spacingS),
          Text(
            loc.setup.chooseUsername,
            style: TextStyle(
              fontSize: r.titleSize,
              fontWeight: FontWeight.bold,
              color: onBg,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 2),
          Text(
            loc.setup.usernameSubtitle,
            style: TextStyle(
              fontSize: r.footerSize,
              color: onBg.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: r.spacingL),
          if (tieneExistente)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
              child: _bannerExistente(this, onBg, glowColor),
            ),
          SizedBox(height: tieneExistente ? r.spacingM : 0),
          CampoUsuario(
            state: state,
            loc: loc,
            r: r,
            onBg: onBg,
            glowColor: glowColor,
            controller: controller,
          ),
          const Spacer(),
          _botones(context, this, glowColor),
          SizedBox(height: r.spacingS),
        ],
      ),
    );
  }
}