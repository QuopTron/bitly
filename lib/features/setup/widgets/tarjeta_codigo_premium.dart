// ─────────────────────────────────────────────────────────────
// tarjeta_codigo_premium.dart — Tarjeta de activación del código
// premium del setup: campo de texto con vidrio, validación contra
// Go (ValidarCodigoPremium), estados (validando/validado/error) y
// botón de activar/reintentar. Solo aparece en modo premium.
// Se conecta con: setup_bloc (CodigoPremiumCambiado,
// ValidarCodigoPremium) + shared (vidrio, botón, responsive) + l10n.
// Parte del flujo: setup (paso 5: modo premium → código).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/boton_vidrio.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_estado.dart';
import '../bloc/setup_evento.dart';

part 'tarjeta_codigo_premium_widgets.dart';

/// Tarjeta de ingreso y validación del código premium.
class TarjetaCodigoPremium extends StatelessWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final Color onBg;
  final Color glowColor;

  const TarjetaCodigoPremium({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: r.spacingM),
      child: ContenedorVidrio(
        borderRadius: 14,
        borderColor: onBg.withValues(alpha: 0.08),
        bgColor: onBg.withValues(alpha: 0.02),
        margin: EdgeInsets.symmetric(horizontal: r.languageCardMargin),
        padding: EdgeInsets.all(r.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.setup.activateCode,
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w600,
                color: onBg,
              ),
            ),
            SizedBox(height: r.spacingXS),
            Text(
              loc.setup.enterCode,
              style: TextStyle(
                fontSize: r.footerSize,
                color: onBg.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: r.spacingM),
            _campo(context, this),
            SizedBox(height: r.spacingM),
            _boton(context, this),
            if (state.errorCodigo != null) ...[
              SizedBox(height: r.spacingS),
              _error(context, this),
            ],
          ],
        ),
      ),
    );
  }

}