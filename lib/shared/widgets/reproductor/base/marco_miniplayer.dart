// ─────────────────────────────────────────────────────────────
// marco_miniplayer.dart — Le da al miniplayer el MARGEN y el ANCHO que resolvió
// su geometría, y lo centra cuando el preset le puso un tope.
//
// Por qué es un widget compartido: los tres shells (celular, PC y tele)
// colocaban el miniplayer cada uno por su cuenta, con sus propios márgenes
// escritos a mano. Con el tope de ancho, repetir la cuenta en tres lugares es
// garantía de que dos queden mal. Acá se resuelve una vez y los tres envuelven.
//
// Sólo toca el EJE HORIZONTAL a propósito: el margen de arriba y de abajo sigue
// siendo de cada shell, porque no es lo mismo la barra pegada a la navbar del
// celular que la tarjeta con aire de la PC. Y va por FUERA del adorno de cada
// shell (borde, sombra, esquinas): si el ancho se acotara por dentro, la tarjeta
// seguiría ocupando la pantalla entera con una barrita centrada adentro.
//
// Se conecta con: miniplayer_geometria.dart (la cuenta) + los tres shells.
// Parte del flujo: presentación (dónde y con qué ancho va el miniplayer).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../utilidades/formato/apariencia/barras/miniplayer_geometria.dart';

/// Margen lateral + ancho máximo (centrado) del miniplayer.
class MarcoMiniplayer extends StatelessWidget {
  /// El miniplayer, con el adorno que le ponga el shell que lo coloca.
  final Widget child;

  const MarcoMiniplayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final g = geometriaMiniplayerDe(context);
    return Padding(
      padding: EdgeInsets.only(
        left: g.margenLateral,
        right: g.margenLateral,
      ),
      // Sin tope se devuelve el hijo tal cual: ni un widget de layout de más
      // (esto corre en el miniplayer, que está en TODAS las pantallas).
      child:
          g.conTope
              ? Center(
                child: SizedBox(width: g.anchoBarra, child: child),
              )
              : child,
    );
  }
}
