// ─────────────────────────────────────────────────────────────
// texto_linea_letra.dart — Una línea de letra del karaoke.
//
// Regla: el texto se ve ENTERO y CENTRADO. Una línea larga envuelve en
// los renglones que necesite; nunca se recorta ni se desplaza en
// horizontal.
//
// Por qué (historia del karaoke): primero se recortaba con "…", después
// se hacía desfilar con una marquesina. Las dos fallaban igual con
// líneas largas: en la marquesina solo se veía una VENTANA del texto a
// la vez —había que esperar a que pasara— y su movimiento era un
// ping-pong por TIEMPO, así que no seguía a la voz: el cantante ya había
// pasado y el texto seguía desfilando. Ahora la línea crece en alto y el
// resaltado avanza DENTRO del texto (por palabra/sílaba, o por
// caracteres cuando la fuente no trae tiempos), que es lo que sí sigue
// al cantante.
//
// El estilo (tamaño, color, glow, peso) lo pone quien lo usa: la línea
// activa y las demás se diferencian con el DefaultTextStyle del karaoke.
//
// Se conecta con: features/reproductor/letras/hoja_letras_linea.dart.
// Parte del flujo: reproductor (letras karaoke).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Línea de letra: envuelve centrada y nunca recorta el texto.
class TextoLineaLetra extends StatelessWidget {
  /// Texto de la línea, o spans con estilo por palabra/sílaba (enhanced LRC).
  final InlineSpan span;

  const TextoLineaLetra({super.key, required this.span});

  @override
  Widget build(BuildContext context) {
    // Sin `maxLines` y sin `softWrap: false`: la línea ocupa el alto que
    // necesite. Tampoco hay `ellipsis` ni desplazamiento horizontal.
    return Text.rich(
      span,
      textAlign: TextAlign.center,
      softWrap: true,
      overflow: TextOverflow.visible,
    );
  }
}
