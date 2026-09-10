// ─────────────────────────────────────────────────────────────
// panel_error.dart — Panel de error del splash: muestra el mensaje
// de error (o el genérico de "Backend no responde") con un botón de
// reintentar que re-dispara el chequeo del backend. Centraliza el
// fallo de arranque para la página de splash.
// Se conecta con: features/splash (página + bloc) + l10n.
// Parte del flujo: splash (error de conexión al backend).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../bloc/splash_bloc.dart';
import '../bloc/splash_estado.dart';
import '../bloc/splash_evento.dart';

/// Mensaje de error + botón reintentar del splash.
class PanelError extends StatelessWidget {
  final EstadoSplash state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const PanelError({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

    return Column(
      children: [
        SizedBox(height: r.spacingXL),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
          child: Text(
            state.error ?? loc.splash.backendNotResponding,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65),
              fontSize: r.subtitleSize,
            ),
          ),
        ),
        SizedBox(height: r.spacingM),
        SizedBox(
          height: r.retryButtonHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: glowColor.withValues(alpha: 0.15),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: glowColor.withValues(alpha: 0.4)),
              ),
            ),
            onPressed: () =>
                context.read<SplashBloc>().add(const ChequearBackend()),
            child: Text(
              loc.splash.retry,
              style: TextStyle(color: glowColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}