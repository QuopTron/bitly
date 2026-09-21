// ─────────────────────────────────────────────────────────────
// busqueda_tv.dart — Variante TV de la búsqueda.
//
// Se diferencia de la de PC en lo que cambia al mirar la tele: el panel es
// PLANO y aprovecha todo el lienzo (1280), con márgenes y separaciones
// grandes, y sin vidrio (el desenfoque de fondo es el gasto más caro en una
// GPU de TV y no se nota a metros). El contenido sigue viniendo armado desde
// la página: acá no hay lógica duplicada.
//
// Se conecta con: pagina_busqueda.dart (padre) + panel_tv.
// Parte del flujo: búsqueda (diseño de TV).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../shared/widgets/indicadores/red/base/indicador_red.dart';
import '../../../shared/widgets/paneles/panel_tv.dart';

/// Layout de TV de la búsqueda (panel plano a todo el lienzo).
class BusquedaTv extends StatelessWidget {
  final Widget barra;
  final Widget chips;
  final Widget cuerpo;

  const BusquedaTv({
    super.key,
    required this.barra,
    required this.chips,
    required this.cuerpo,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = ColoresApp.enSuperficie(
      Theme.of(context).brightness == Brightness.dark,
    );

    return PanelTv(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador global de red: barra superior de la sección.
          Align(
            alignment: Alignment.centerRight,
            child: IndicadorRed(onBg: onBg, conEtiqueta: true),
          ),
          SizedBox(height: r.spacingS),
          barra,
          SizedBox(height: r.spacingS),
          chips,
          SizedBox(height: r.spacingXS),
          Expanded(child: cuerpo),
        ],
      ),
    );
  }
}
