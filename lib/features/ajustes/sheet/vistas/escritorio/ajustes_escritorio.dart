// ─────────────────────────────────────────────────────────────
// ajustes_escritorio.dart — Hoja de Ajustes en PC: el mismo panel anclado
// abajo, pero con el navegador (riel) al COSTADO del contenido y un ancho
// máximo, para que en un monitor grande no quede todo estirado de borde a
// borde.
//
// El riel a la izquierda es lo que hace legible el menú en pantalla ancha: las
// pestañas entran con su nombre completo y el contenido no se aprieta. El
// ancho máximo centra ese conjunto y es la única diferencia real con el
// celular, además de la posición del navegador.
//
// No decide nada por su cuenta: recibe el [MarcoAjustes] con los tres slots ya
// armados (cabecera, navegación y contenido) y sólo los ubica.
//
// Se conecta con: ajustes_marco.dart (lo elige y le pasa el marco) +
// settings_sheet_body_state.dart (lo monta).
// Parte del flujo: Ajustes (armado de la hoja en PC).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../shared/tema/especificaciones/especificaciones_plataforma.dart';
import '../../../../../shared/utilidades/plataforma/pantalla/insets_sistema.dart';
import '../base/ajustes_marco.dart';

/// La hoja de Ajustes tal como se ve en la computadora.
class AjustesEscritorio extends StatelessWidget {
  final MarcoAjustes marco;

  const AjustesEscritorio({super.key, required this.marco});

  @override
  Widget build(BuildContext context) {
    final r = marco.r;
    final esp = EspecificacionesPlataforma.de(context);
    final radio = BorderRadius.vertical(top: Radius.circular(esp.radioHoja));
    // Ancho máximo del conjunto navegador + contenido: se ensancha con la
    // pantalla y con el aparato, pero no se estira sin límite.
    final anchoMax = r.val(1180, 900, 1500);

    final hoja = Container(
      height: MediaQuery.sizeOf(context).height * 0.8,
      margin: EdgeInsets.only(top: r.spacingXL),
      decoration: BoxDecoration(
        color: marco.hasTrack ? Colors.transparent : marco.bg,
        borderRadius: radio,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: marco.isDark ? 0.45 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radio,
        child: Column(
          children: [
            SizedBox(height: r.spacingM),
            tiradorAjustes(marco),
            SizedBox(height: r.spacingM),
            marco.cabecera,
            SizedBox(height: r.spacingM),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: insetInferiorSistema(context)),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: anchoMax),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        marco.navegacion,
                        SizedBox(width: r.spacingM),
                        Expanded(child: marco.contenido),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return conVidrioAjustes(context, marco, hoja);
  }
}
