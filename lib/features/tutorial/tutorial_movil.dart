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
    return Scaffold(
      backgroundColor: esOscuro ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: cuerpo),
            const SizedBox(height: 8),
            controles,
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}