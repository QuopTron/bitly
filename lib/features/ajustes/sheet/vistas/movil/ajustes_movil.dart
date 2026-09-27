// ─────────────────────────────────────────────────────────────
// ajustes_movil.dart — Hoja de Ajustes en CELULAR (y tablet vertical): el
// panel que sube desde abajo, con el perfil arriba, las pestañas burbuja
// debajo y el contenido ocupando el resto.
//
// Es el diseño de siempre, ahora en su propio archivo: la hoja ocupa el 80%
// del alto, deja ver la página de atrás y reserva el borde inferior del
// sistema para que el último control de cada pestaña no quede debajo del menú
// de navegación.
//
// No decide nada por su cuenta: recibe el [MarcoAjustes] con los tres slots ya
// armados (cabecera, navegación y contenido) y sólo los ubica.
//
// Se conecta con: ajustes_marco.dart (lo elige y le pasa el marco) +
// settings_sheet_body_state.dart (lo monta).
// Parte del flujo: Ajustes (armado de la hoja en celular).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../shared/tema/especificaciones/especificaciones_plataforma.dart';
import '../../../../../shared/utilidades/plataforma/pantalla/insets_sistema.dart';
import '../base/ajustes_marco.dart';

/// La hoja de Ajustes tal como se ve en el teléfono.
class AjustesMovil extends StatelessWidget {
  final MarcoAjustes marco;

  const AjustesMovil({super.key, required this.marco});

  @override
  Widget build(BuildContext context) {
    final r = marco.r;
    final esp = EspecificacionesPlataforma.de(context);
    final radio = BorderRadius.vertical(top: Radius.circular(esp.radioHoja));

    final hoja = Container(
      // Más alto que la mitad: deja el contexto de la página asomando arriba.
      height: MediaQuery.sizeOf(context).height * 0.8,
      margin: EdgeInsets.only(top: r.spacingXL),
      decoration: BoxDecoration(
        // Transparente si hay cover: el tinte lo pone el fondo desenfocado.
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
                // El menú de navegación del celular tapa el borde físico.
                padding: EdgeInsets.only(bottom: insetInferiorSistema(context)),
                child: Column(
                  children: [
                    marco.navegacion,
                    SizedBox(height: r.spacingS),
                    Expanded(child: marco.contenido),
                  ],
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
