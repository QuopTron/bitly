// ─────────────────────────────────────────────────────────────
// tutorial_escritorio.dart — Variante ESCRITORIO del tutorial:
// panel de vidrio centrado con ancho máximo, con el cuerpo
// (PageView de pasos) y los controles (indicadores + botón).
// Recibe los widgets ya construidos desde la página para no
// duplicar lógica.
// Se conecta con: tutorial_pagina.dart (padre) + contenedor_vidrio.
// Parte del flujo: arranque (primer uso, layout escritorio).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../shared/widgets/vidrio/base/contenedor_vidrio.dart';

/// Layout escritorio del tutorial: panel centrado con ancho máximo.
class TutorialEscritorio extends StatelessWidget {
  final Widget cuerpo;
  final Widget controles;

  const TutorialEscritorio({
    super.key,
    required this.cuerpo,
    required this.controles,
  });

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    // El panel se mide con el aparato: en la tele el ancho máximo y el aire
    // crecen, así no queda una tarjeta chica al medio de la pantalla.
    final r = Responsive(context);
    return Scaffold(
      backgroundColor: ColoresApp.fondo(esOscuro),
      body: Center(
        child: ContenedorVidrio(
          padding: EdgeInsets.symmetric(
            horizontal: r.sobre(48, 72),
            vertical: r.sobre(40, 60),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: r.sobre(560, 780)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: r.sobre(320, 460), child: cuerpo),
                SizedBox(height: r.spacingS),
                controles,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
