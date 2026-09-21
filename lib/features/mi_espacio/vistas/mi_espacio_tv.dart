// ─────────────────────────────────────────────────────────────
// mi_espacio_tv.dart — Variante TV de Mi Espacio.
//
// Igual criterio que las otras secciones: el panel PLANO de TV a todo el
// lienzo, con la cabecera (perfil + banner) y el cuerpo (pestañas + contenido)
// que ya vienen armados desde la página. Sin vidrio ni desenfoque, que a
// metros no se notan y en una GPU de tele se pagan en cada frame.
//
// Se conecta con: pagina_mi_espacio.dart (padre) + panel_tv.
// Parte del flujo: Home → Mi Espacio (diseño de TV).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/widgets/paneles/panel_tv.dart';

/// Layout de TV de Mi Espacio (panel plano a todo el lienzo).
class MiEspacioTv extends StatelessWidget {
  final Widget cabecera;
  final Widget cuerpo;

  const MiEspacioTv({super.key, required this.cabecera, required this.cuerpo});

  @override
  Widget build(BuildContext context) => PanelTv(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [cabecera, const SizedBox(height: 10), Expanded(child: cuerpo)],
    ),
  );
}
