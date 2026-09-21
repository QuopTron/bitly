// ─────────────────────────────────────────────────────────────
// detalle_tv.dart — Variante TV del detalle (álbum, artista y playlist).
//
// Por qué no reusa la cabecera de celular/PC: esa es una columna centrada con
// la carátula difuminada de fondo (bonita en un teléfono, cara y desaprovechada
// en una tele). En TV la pantalla es ancha y se mira a metros, así que acá van
// DOS COLUMNAS —portada, título, subtítulo, distintivo y acciones a la
// izquierda; la lista de canciones a la derecha, con su propio scroll— sobre
// superficie PLANA: sin velo difuminado, sin glow y sin capas de fondo (en una
// GPU de TV esas capas se rehacen en cada frame y a tres metros no se notan).
//
// Recibe las MISMAS piezas que ya arma cada página (portada, textos, distintivo,
// acciones y los hijos del detalle), así que no hay lógica duplicada: la página
// decide qué mostrar y esta variante solo lo ordena para una tele.
//
// Se conecta con: album_detalle_pagina, artista_detalle_pagina y
// playlist_detalle_pagina (los tres la usan) + imagen_portada + colores_app.
// Parte del flujo: Detalle (variante TV).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../shared/tema/colores_app.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../shared/widgets/tarjetas/portada/imagen_portada.dart';

/// Detalle de TV: dos columnas, fondo plano y lista con scroll propio.
class DetalleTv extends StatelessWidget {
  final String? coverUrl;
  final String titulo;
  final String subtitulo;
  final String? badge;
  final Widget? acciones;
  final List<Widget> children;

  /// Etiqueta del Hero, para que la transición desde la grilla siga volando.
  final String? heroTag;

  /// Alto del lienzo de TV (ver vista_tv): se usa para dimensionar la portada.
  const DetalleTv({
    super.key,
    this.coverUrl,
    required this.titulo,
    required this.subtitulo,
    this.badge,
    this.acciones,
    this.children = const [],
    this.heroTag,
  });

  /// Ancho de la columna izquierda (portada + datos).
  static const double _anchoColumna = 400;

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final r = Responsive(context);
    final colorFondo = ColoresApp.fondo(esOscuro);
    final onBg = ColoresApp.enSuperficie(esOscuro);

    return Scaffold(
      backgroundColor: colorFondo,
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _anchoColumna,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(30, 26, 18, 26),
                      child: _columnaDatos(r, onBg),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                // La lista va con SU scroll: en una tele se recorre con el
                // control y así la portada y los datos quedan siempre a la vista.
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 26, 30, 120),
                    children: children,
                  ),
                ),
              ],
            ),
            // Retroceso: en la tele el control remoto tiene su tecla, pero el
            // puntero también puede tocar acá.
            Positioned(
              left: 8,
              top: 6,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icon(Icons.arrow_back_rounded, color: onBg),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Columna izquierda: portada, textos, distintivo y acciones.
  Widget _columnaDatos(Responsive r, Color onBg) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: r.spacingL),
      Hero(
        tag: heroTag ?? titulo,
        child: ImagenPortada(
          coverUrl: coverUrl,
          ancho: 300,
          alto: 300,
          radioBorde: 20,
        ),
      ),
      SizedBox(height: r.spacingM),
      Text(
        titulo,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          // Más grande que en celular y PC: se lee desde el sillón.
          fontSize: r.subtitleSize * 1.5,
          fontWeight: FontWeight.w800,
          color: onBg,
          height: 1.1,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        subtitulo,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: r.subtitleSize,
          fontWeight: FontWeight.w500,
          color: onBg.withValues(alpha: 0.75),
        ),
      ),
      if (badge != null) ...[
        const SizedBox(height: 6),
        Text(
          badge!,
          style: TextStyle(
            fontSize: r.footerSize + 1,
            color: onBg.withValues(alpha: 0.55),
          ),
        ),
      ],
      if (acciones != null) ...[SizedBox(height: r.spacingS), acciones!],
    ],
  );
}
