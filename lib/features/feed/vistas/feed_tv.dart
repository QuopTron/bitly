// ─────────────────────────────────────────────────────────────
// feed_tv.dart — Variante TV del feed (Inicio).
//
// Mismo contenido que las otras dos variantes, pero apoyado en el panel PLANO
// de TV a todo el lienzo: márgenes grandes, sin vidrio y con la cabecera
// (saludo + selector de fuente) separada del cuerpo por más aire, que es lo
// que se lee bien a metros. La cabecera y el cuerpo llegan armados desde la
// página, así que acá no hay lógica duplicada.
//
// Se conecta con: feed_pagina.dart (padre) + panel_tv.
// Parte del flujo: Home → Inicio (diseño de TV).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../shared/widgets/paneles/panel_tv.dart';

/// Layout de TV del feed (panel plano a todo el lienzo).
class FeedTv extends StatelessWidget {
  final Widget cabecera;
  final Widget cuerpo;

  const FeedTv({super.key, required this.cabecera, required this.cuerpo});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return PanelTv(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          cabecera,
          SizedBox(height: r.spacingM),
          Expanded(child: cuerpo),
        ],
      ),
    );
  }
}
