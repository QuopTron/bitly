// ─────────────────────────────────────────────────────────────
// tarjeta_info_cuenta.dart — Tarjeta con el resumen de la cuenta
// existente en el prompt de reingreso: idioma, usuario, modo
// (free/premium), estado del trial (activo/expirado). Se usa en el
// paso de "¿Continuar con tu cuenta?".
// Se conecta con: prompt_reingreso.dart + setup_estado + l10n.
// Parte del flujo: setup (paso 1: reingreso).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';
import '../bloc/setup_estado.dart';

/// Resumen de la cuenta existente.
class TarjetaInfoCuenta extends StatelessWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final Color onBg;
  final Color glowColor;

  const TarjetaInfoCuenta({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return ContenedorVidrio(
      borderRadius: 14,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.02),
      margin: EdgeInsets.symmetric(horizontal: r.spacingXL),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        children: [
          _fila(
            Icons.language,
            state.idiomaExistente == 'es'
                ? loc.setup.espanol
                : loc.setup.english,
          ),
          if ((state.usuarioExistente ?? '').isNotEmpty) ...[
            SizedBox(height: r.spacingXS),
            _fila(Icons.person, state.usuarioExistente!),
          ],
          SizedBox(height: r.spacingXS),
          _fila(
            state.modoExistente == 'free' ? Icons.music_note : Icons.verified,
            '${state.modoExistente == 'free' ? loc.setup.free : loc.setup.premium} — ${state.modoExistente == 'free' ? loc.setup.freeInfo : loc.setup.premiumInfo}',
          ),
          SizedBox(height: r.spacingXS),
          if (state.trialExistenteExpirado)
            _fila(Icons.warning_amber, loc.setup.trialExpired, color: glowColor)
          else if (state.modoExistente == 'free')
            _fila(Icons.timer_outlined, loc.setup.trialActive, color: glowColor),
        ],
      ),
    );
  }

  Widget _fila(IconData icon, String text, {Color? color}) {
    final c = color ?? onBg;
    return Row(
      children: [
        Icon(icon, size: r.footerSize + 4, color: c),
        SizedBox(width: r.spacingS),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: r.footerSize + 1, color: c),
          ),
        ),
      ],
    );
  }
}