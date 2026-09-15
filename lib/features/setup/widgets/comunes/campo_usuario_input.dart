// ─────────────────────────────────────────────────────────────
// campo_usuario_input.dart — Input de vidrio del nombre de usuario
// del setup, con el dado que pide un nombre aleatorio. Emite
// UsuarioCambiado al escribir y GenerarNombreAleatorio al tocar el
// dado.
// Se conecta con: setup_bloc + contenedor_vidrio + responsive + l10n.
// Parte del flujo: setup (paso 3: nombre de usuario).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../shared/widgets/vidrio/contenedor_vidrio.dart';
import '../../bloc/setup_bloc.dart';
import '../../bloc/setup_evento.dart';

/// Caja de texto del nombre de usuario + botón de nombre aleatorio.
class InputUsuarioNombre extends StatelessWidget {
  final AppLocalizations loc;
  final Responsive r;
  final Color onBg;
  final Color glowColor;
  final TextEditingController controller;

  const InputUsuarioNombre({
    super.key,
    required this.loc,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ContenedorVidrio(
      borderRadius: 12,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: loc.setup.usernameHint,
                hintStyle: TextStyle(
                  color: onBg.withValues(alpha: 0.35),
                  fontSize: r.footerSize,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: r.spacingM,
                  vertical: r.spacingS + 2,
                ),
              ),
              style: TextStyle(color: onBg, fontSize: r.subtitleSize),
              textCapitalization: TextCapitalization.words,
              onChanged: (val) =>
                  context.read<SetupBloc>().add(UsuarioCambiado(val)),
            ),
          ),
          _dado(context),
        ],
      ),
    );
  }

  Widget _dado(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<SetupBloc>().add(const GenerarNombreAleatorio()),
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          color: glowColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.casino,
          color: glowColor,
          size: r.languageCardIconSize * 0.75,
        ),
      ),
    );
  }
}
