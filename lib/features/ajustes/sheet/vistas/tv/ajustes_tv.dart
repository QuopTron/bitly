// ─────────────────────────────────────────────────────────────
// ajustes_tv.dart — Hoja de Ajustes en TELEVISOR (Android TV / Google TV /
// Fire TV): panel PLANO a todo el lienzo, riel de pestañas al costado y más
// aire, porque se navega a metros con el control remoto.
//
// Diferencias con el celular y la PC, todas por la regla de vistas:
//   · PLANO: sin esquinas redondeadas, sin sombra y sin vidrio/desenfoque (el
//     desenfoque se paga en cada frame y a metros no se distingue);
//   · a todo el lienzo: la hoja ocupa el alto disponible, así cada fila queda
//     grande y con blanco alrededor para el puntero del control;
//   · sin tirador: en la tele no se arrastra para cerrar (se navega con el
//     D-pad y el puntero), así que el tirador sólo sería decoración;
//   · el navegador va al costado (riel de TV, más ancho y con filas grandes).
//
// No decide nada por su cuenta: recibe el [MarcoAjustes] con los tres slots ya
// armados (cabecera, navegación y contenido) y sólo los ubica.
//
// Se conecta con: ajustes_marco.dart (lo elige y le pasa el marco) +
// settings_sheet_body_state.dart (lo monta).
// Parte del flujo: Ajustes (armado de la hoja en TV).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../shared/tema/especificaciones/especificaciones_plataforma.dart';
import '../../../../../shared/utilidades/plataforma/pantalla/insets_sistema.dart';
import '../base/ajustes_marco.dart';

/// La hoja de Ajustes tal como se ve en la tele.
class AjustesTv extends StatelessWidget {
  final MarcoAjustes marco;

  const AjustesTv({super.key, required this.marco});

  @override
  Widget build(BuildContext context) {
    // Se pregunta por el aparato aunque el número no se use: deja escrito que
    // este panel crece con el perfil de TV (1.45×) y que el lienzo lógico lo
    // pone vista_tv. El marco ya trae ese `Responsive`.
    final esp = EspecificacionesPlataforma.de(context);
    final r = marco.r;
    // El aire de arriba: en la tele el panel llega hasta el borde del lienzo.
    final margen = esp.radioHoja / 4;

    // Se mide con lo que dejó la hoja modal (no con el alto de la pantalla):
    // si el sistema reserva algo abajo, el panel se achica en vez de desbordar.
    return LayoutBuilder(
      builder: (context, c) {
        final disponible =
            c.maxHeight.isFinite
                ? c.maxHeight
                : MediaQuery.sizeOf(context).height;
        return Container(
          // Alto del lienzo: en la tele no hay hoja "que sube".
          height: disponible - margen,
          margin: EdgeInsets.only(top: margen),
          // Opaco a propósito: nada de vidrio (regla de TV).
          color: marco.bg,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              r.spacingL,
              r.spacingL,
              r.spacingL,
              r.spacingL + insetInferiorSistema(context),
            ),
            child: Column(
              children: [
                marco.cabecera,
                SizedBox(height: r.spacingL),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      marco.navegacion,
                      SizedBox(width: r.spacingXL),
                      Expanded(child: marco.contenido),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
