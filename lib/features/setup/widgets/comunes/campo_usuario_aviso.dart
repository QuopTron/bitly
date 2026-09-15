// ─────────────────────────────────────────────────────────────
// campo_usuario_aviso.dart — Badge de confirmación del nombre
// elegido y aviso de una sola línea sobre la cuenta de Soulseek
// (aviso / conectando / rechazo por nombre tomado o inválido).
// Se conecta con: setup_estado (SyncSoulseek) + contenedor_vidrio +
// responsive + l10n.
// Parte del flujo: setup (paso 3: nombre de usuario).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../shared/widgets/vidrio/contenedor_vidrio.dart';
import '../../bloc/setup_estado.dart';

/// Chip que confirma el nombre de usuario ya escrito.
class BadgeUsuarioNombre extends StatelessWidget {
  final String usuario;
  final Responsive r;
  final Color glowColor;

  const BadgeUsuarioNombre({
    super.key,
    required this.usuario,
    required this.r,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: r.spacingS),
      child: ContenedorVidrio(
        borderRadius: 8,
        borderColor: glowColor.withValues(alpha: 0.2),
        bgColor: glowColor.withValues(alpha: 0.06),
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingM,
          vertical: r.spacingXS,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: glowColor, size: r.footerSize),
            SizedBox(width: r.spacingXS),
            Flexible(
              child: Text(
                usuario,
                style: TextStyle(
                  color: glowColor,
                  fontSize: r.footerSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una sola línea, con tres estados: aviso, conectando y rechazo.
///
/// Esto sigue siendo el paso del nombre, no un formulario de Soulseek. La
/// cuenta se crea al continuar, pero el usuario ve qué va a pasar antes de
/// tocar el botón. Y si el nombre ya está tomado, el rechazo aparece acá —en
/// el mismo lugar donde lo puede arreglar— en vez de al final del setup.
class AvisoEstadoUsuario extends StatelessWidget {
  final EstadoSetup state;
  final Responsive r;
  final Color onBg;
  final AppLocalizations loc;

  const AvisoEstadoUsuario({
    super.key,
    required this.state,
    required this.r,
    required this.onBg,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final creando = state.syncSoulseek == SyncSoulseek.creando;
    final motivo = state.motivoSoulseek;
    final bloqueado = state.syncSoulseek == SyncSoulseek.fallo &&
        (motivo == 'nombre_tomado' || motivo == 'nombre_invalido');

    final Color color = bloqueado
        ? Colors.red.shade400
        : onBg.withValues(alpha: creando ? 0.55 : 0.45);
    final String texto = switch (motivo) {
      'nombre_tomado' => loc.setup.soulseekNameTaken,
      'nombre_invalido' => loc.setup.soulseekNameInvalid,
      _ => loc.setup.soulseekAccountNotice,
    };

    return Padding(
      padding: EdgeInsets.only(top: r.spacingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (creando)
            SizedBox(
              width: r.footerSize - 1,
              height: r.footerSize - 1,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: onBg.withValues(alpha: 0.55),
              ),
            )
          else
            Icon(
              bloqueado ? Icons.error_outline : Icons.hub_rounded,
              size: r.footerSize - 1,
              color: color,
            ),
          SizedBox(width: r.spacingXS),
          Flexible(
            child: Text(
              creando ? loc.setup.soulseekConnecting : texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: color,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
