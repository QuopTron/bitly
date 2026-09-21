// ─────────────────────────────────────────────────────────────
// tutorial_tv.dart — Variante TV del tutorial: el cuerpo (PageView de pasos) y
// los controles dentro del panel PLANO de TV, con más alto y más margen que en
// PC para que se lea y se toque desde el sillón.
//
// El cuerpo y los controles llegan armados desde la página: acá no hay lógica
// duplicada, solo la forma de presentarlos en una tele.
//
// Se conecta con: tutorial_pagina.dart (padre) + panel_tv.
// Parte del flujo: arranque (primer uso, variante TV).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/tema/colores_app.dart';
import '../../../shared/widgets/paneles/panel_tv.dart';

/// Layout de TV del tutorial: panel plano centrado y más alto.
class TutorialTv extends StatelessWidget {
  final Widget cuerpo;
  final Widget controles;

  const TutorialTv({super.key, required this.cuerpo, required this.controles});

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: ColoresApp.fondo(esOscuro),
      body: PanelTv(
        anchoMaximo: 760,
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 46),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Más alto que en PC (320): a metros, el paso necesita aire.
            SizedBox(height: 380, child: cuerpo),
            const SizedBox(height: 12),
            controles,
          ],
        ),
      ),
    );
  }
}
