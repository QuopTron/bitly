// ─────────────────────────────────────────────────────────────
// campo_usuario.dart — Campo del nombre de usuario del setup:
// compone el input de vidrio (con el dado), el badge de confirmación
// y el aviso de Soulseek. Las piezas viven en campo_usuario_input.dart
// y campo_usuario_aviso.dart.
// Se conecta con: setup_bloc/setup_estado + campo_usuario_input +
// campo_usuario_aviso + l10n.
// Parte del flujo: setup (paso 3: nombre de usuario).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';
import '../../bloc/setup_estado.dart';
import 'campo_usuario_aviso.dart';
import 'campo_usuario_input.dart';

/// Campo de nombre de usuario con generador aleatorio.
class CampoUsuario extends StatelessWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final Color onBg;
  final Color glowColor;
  final TextEditingController controller;

  const CampoUsuario({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: Column(
        children: [
          InputUsuarioNombre(
            loc: loc,
            r: r,
            onBg: onBg,
            glowColor: glowColor,
            controller: controller,
          ),
          if (state.usuario.trim().isNotEmpty)
            BadgeUsuarioNombre(
              usuario: state.usuario,
              r: r,
              glowColor: glowColor,
            ),
          AvisoEstadoUsuario(state: state, r: r, onBg: onBg, loc: loc),
        ],
      ),
    );
  }
}
