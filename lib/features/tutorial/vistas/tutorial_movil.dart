// ─────────────────────────────────────────────────────────────
// tutorial_movil.dart — Variante MÓVIL del tutorial: columna a
// pantalla completa con el cuerpo (PageView de pasos) en un
// Expanded y los controles (indicadores + botón) abajo. Recibe
// los widgets ya construidos desde la página para no duplicar
// lógica.
// Se conecta con: tutorial_pagina.dart (padre).
// Parte del flujo: arranque (primer uso, layout móvil).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/utilidades/plataforma/responsive.dart';

/// Layout móvil del tutorial (diseño Android actual).
class TutorialMovil extends StatelessWidget {
  final Widget cuerpo;
  final Widget controles;

  const TutorialMovil({
    super.key,
    required this.cuerpo,
    required this.controles,
  });

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    // Las separaciones salen de Responsive, no de un 8/32 fijo: crecen con la
    // pantalla y con el aparato (en la tele el botón queda más despegado).
    final r = Responsive(context);
    return Scaffold(
      backgroundColor: esOscuro ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: cuerpo),
            SizedBox(height: r.spacingS),
            controles,
            SizedBox(height: r.sobre(32, 48)),
          ],
        ),
      ),
    );
  }
}
