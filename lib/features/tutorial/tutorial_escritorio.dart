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

import '../../shared/tema/colores_app.dart';
import '../../shared/widgets/contenedor_vidrio.dart';

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
    return Scaffold(
      backgroundColor: ColoresApp.fondo(esOscuro),
      body: Center(
        child: ContenedorVidrio(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 320, child: cuerpo),
                const SizedBox(height: 8),
                controles,
              ],
            ),
          ),
        ),
      ),
    );
  }
}