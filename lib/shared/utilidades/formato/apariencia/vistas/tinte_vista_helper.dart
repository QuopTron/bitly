// ─────────────────────────────────────────────────────────────
// tinte_vista_helper.dart — El TINTE de las cards de una vista cuando esa
// pantalla tiene una PALETA del cofre puesta (Ajustes → Apariencia → Vistas).
//
// Por qué existe: el color de las cards salía siempre de la carátula
// (`EstiloHelper` + la extracción del dominante). Con el cofre por vista, la
// vista puede decir el color ELLA, y eso hay que resolverlo en un solo lugar
// porque lo usan la card de canción y la de grilla, con las dos reglas
// siguientes.
//
//  1. La paleta MANDA sobre el color del cover. Elegir una paleta es una
//     decisión explícita del usuario: si el cover pudiera pisarla, elegirla no
//     serviría de nada.
//  2. La paleta tiñe AUNQUE el estilo con cover esté apagado. Si no, elegir una
//     paleta con el deslizador de Estilo en 0 no se vería —un control que no
//     hace nada—, que es el fallo que más caro sale. Por eso hay un PISO de
//     intensidad; por encima de ese piso el deslizador sigue mandando.
//
// Y un beneficio gratis: con paleta NO se extrae el color dominante del cover,
// así que esa decodificación por tarjeta se evita en toda la vista.
//
// Se conecta con: ambito_vista.dart (la paleta de la vista) + estilo_helper
// (el tinte del cover) + las dos cards.
// Parte del flujo: Ajustes → Apariencia → Vistas, y el pintado de las cards.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../widgets/vista/base/ambito_vista.dart';
import '../../comun/formato/estilo_helper.dart';

/// Tinte de las cards según la paleta que tenga puesta esa vista.
class TinteVista {
  TinteVista._();

  /// Intensidad mínima cuando la vista tiene paleta.
  ///
  /// 0.6 y no 1: al máximo el color tapa la carátula y la card deja de
  /// parecerse a su portada. Con 0.6 la paleta se nota claramente y la foto
  /// se sigue viendo.
  static const piso = 0.6;

  /// El color de la paleta de la vista (el primero), o null si no tiene.
  static Color? acentoDe(BuildContext context) {
    final paleta = AmbitoVista.paletaDe(context);
    return paleta.isEmpty ? null : paleta.first;
  }

  /// ¿La vista en la que está este contexto eligió una paleta?
  static bool activo(BuildContext context) => acentoDe(context) != null;

  /// El acento que hay que pintar: la paleta de la vista si tiene, y si no el
  /// que venga del cover.
  static Color? acentoDeCards(BuildContext context, Color? delCover) =>
      acentoDe(context) ?? delCover;

  /// La intensidad efectiva de las cards.
  static double nivelDeCards(BuildContext context, double delEstilo) {
    if (!activo(context)) return delEstilo;
    return delEstilo < piso ? piso : delEstilo;
  }

  /// ¿Vale la pena extraer el color dominante del cover?
  static bool extraerDelCover(BuildContext context) => !activo(context);

  /// La intensidad que le toca a una GRILLA de esta vista.
  ///
  /// El espaciado de la grilla se CIERRA a medida que crece la intensidad (las
  /// cards se pegan cuando hay color del cover). Por eso la grilla tiene que
  /// medir lo MISMO que sus cards: midiendo el nivel global, con una paleta
  /// puesta y el deslizador de Estilo en 0 las cards saldrían teñidas y la
  /// grilla con el aire de "sin color" — dos piezas de la misma pantalla
  /// diciendo cosas distintas del mismo ajuste.
  static double nivelDeGrilla(BuildContext context) =>
      nivelDeCards(context, EstiloHelper.cardsGrilla(context));
}
