// ─────────────────────────────────────────────────────────────
// feed_escritorio.dart — Variante escritorio del feed: panel de
// vidrio centrado con ancho máximo que contiene la cabecera
// (saludo + selector de fuente) y el cuerpo (tarjetas/grillas/
// estados). Todo el contenido viene construido desde la página
// para no duplicar lógica.
// Se conecta con: feed_pagina.dart (padre) + contenedor_vidrio.
// Parte del flujo: Home → Inicio (diseño de escritorio).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/contenedor_vidrio.dart';

/// Layout de escritorio del feed (panel centrado).
class FeedEscritorio extends StatelessWidget {
  final Widget cabecera;
  final Widget cuerpo;

  const FeedEscritorio({
    super.key,
    required this.cabecera,
    required this.cuerpo,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: r.spacingXL, vertical: r.spacingL),
          child: ContenedorVidrio(
            borderRadius: 20,
            borderColor: onBg.withValues(alpha: 0.08),
            bgColor: onBg.withValues(alpha: 0.02),
            padding: EdgeInsets.all(r.spacingM),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                cabecera,
                SizedBox(height: r.spacingM),
                Expanded(child: cuerpo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}