// ─────────────────────────────────────────────────────────────
// feed_movil.dart — Variante móvil del feed: columna full-width
// con la cabecera (saludo + selector de fuente) arriba y el cuerpo
// (tarjetas/grillas/estados) en un Expanded. Todo el contenido
// viene construido desde la página para no duplicar lógica.
// Se conecta con: feed_pagina.dart (padre).
// Parte del flujo: Home → Inicio (diseño Android actual).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/utilidades/responsive.dart';

/// Layout móvil del feed (diseño Android actual).
class FeedMovil extends StatelessWidget {
  final Widget cabecera;
  final Widget cuerpo;

  const FeedMovil({
    super.key,
    required this.cabecera,
    required this.cuerpo,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Column(
      children: [
        SizedBox(height: r.spacingM),
        cabecera,
        SizedBox(height: r.spacingM),
        Expanded(child: cuerpo),
      ],
    );
  }
}