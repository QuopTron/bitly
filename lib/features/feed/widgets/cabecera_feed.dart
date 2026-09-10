// ─────────────────────────────────────────────────────────────
// cabecera_feed.dart — Cabecera del feed de inicio: saludo según
// la hora (buenos días/tardes/noches), el username del setup y el
// selector de fuente (AcordeonFuente) con las fuentes que el
// backend realmente devolvió con contenido.
// Se conecta con: l10n + acordeon_fuente + bloc_feed (estado y
// cambio de fuente) + responsive.
// Parte del flujo: feed de inicio (cabecera).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/acordeon_fuente.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_evento.dart';

/// Cabecera del feed: saludo + username + selector de fuente.
class CabeceraFeed extends StatelessWidget {
  final Color onBg;
  final Color colorBrillo;

  /// Fuentes con contenido del home feed (source → nombre legible).
  final Map<String, String> fuentes;

  const CabeceraFeed({
    super.key,
    required this.onBg,
    required this.colorBrillo,
    required this.fuentes,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);
    final state = context.watch<BlocFeed>().state;
    final hora = DateTime.now().hour;
    final saludo = hora < 12
        ? loc.setup.feedGoodMorning
        : hora < 18
            ? loc.setup.feedGoodAfternoon
            : loc.setup.feedGoodEvening;
    final tieneNombre = state.usuario.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saludo,
                  style: TextStyle(
                    fontSize: r.titleSize * 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: onBg,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (tieneNombre) ...[
                  SizedBox(height: 2),
                  Text(
                    state.usuario,
                    style: TextStyle(
                      fontSize: r.footerSize,
                      fontWeight: FontWeight.w500,
                      color: onBg.withValues(alpha: 0.45),
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (fuentes.isNotEmpty) ...[
            SizedBox(width: r.spacingM),
            AcordeonFuente(
              fuentes: fuentes,
              fuenteSeleccionada: state.fuenteSeleccionada,
              onBg: onBg,
              colorBrillo: onBg,
              onCambiada: (v) =>
                  context.read<BlocFeed>().add(FuenteFeedCambiada(v)),
            ),
          ],
        ],
      ),
    );
  }
}