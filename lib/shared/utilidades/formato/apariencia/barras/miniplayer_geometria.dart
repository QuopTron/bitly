// ─────────────────────────────────────────────────────────────
// miniplayer_geometria.dart — Las MEDIDAS del miniplayer resueltas para el
// aparato y el preset que eligió el usuario (Ajustes → Apariencia → Barras).
//
// Por qué existe: hasta hoy cada shell decidía sus propios números —el celular
// lo pegaba al borde, la PC le ponía 18 px de margen con sombra, la tele 22 sin
// sombra, y la carátula salía de `Responsive`—. Con los números repartidos en
// tres archivos, un preset era imposible y cualquier ajuste se desincronizaba
// en dos de los tres. Acá se resuelven UNA vez y los tres leen lo mismo.
//
// Regla de oro: con el preset de fábrica (normal + auto) los números salen
// EXACTAMENTE como hoy. Los presets multiplican las medidas base del aparato, no
// las reemplazan: el que no toca nada ve la app de siempre.
//
// Las ACOTADAS son lo que evita las salidas de diseño, y son la razón de que
// esto sea una función pura y no una cuenta suelta en cada shell:
//   · el margen nunca se come más del 6% del ancho (en una ventana angosta un
//     miniplayer flotante con margen fijo dejaba la barra del tamaño de un
//     sello);
//   · la carátula nunca pasa el 22% del ancho (con "grande" en un celular
//     chico se comía el título y los controles);
//   · los iconos crecen MENOS que la carátula, por lo mismo;
//   · el ANCHO de la barra tiene tope (ver AnchoMiniplayer) y, cuando lo usa,
//     la barra va centrada: en una tele la barra de lado a lado obliga al ojo a
//     viajar de un control al otro;
//   · el relleno interno se mide contra la BARRA y no contra la pantalla —si no,
//     en una barra acotada el 4% de una pantalla enorme se comía el contenido.
//
// Se conecta con: preferencias_apariencia.dart (los presets) +
// apariencia_barras_helper + miniplayer (que pinta) + los 3 shells (que
// colocan).
// Parte del flujo: presentación (el miniplayer en cada aparato).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import '../../../plataforma/deteccion_plataforma.dart';
import '../../../plataforma/responsive.dart';
import '../base/apariencia_helper.dart';

/// Medidas finales del miniplayer para el aparato y el preset actuales.
class MiniplayerGeometria {
  /// Lado de la carátula, en píxeles lógicos.
  final double ladoCaratula;

  /// Redondeo de la carátula.
  final double radioCaratula;

  /// Margen lateral contra los bordes de la pantalla. 0 = pegado al borde.
  final double margenLateral;

  /// ¿Es una tarjeta con márgenes (en vez de una barra de ancho completo)?
  final bool flotante;

  /// ¿Lleva sombra? En la tele no: a metros no se ve y se recompone en cada
  /// frame, así que es costo sin beneficio.
  final bool conSombra;

  /// Cuánto crecen los iconos de control.
  final double factorIconos;

  /// Ancho de la pantalla con el que se resolvió.
  final double anchoDisponible;

  /// Ancho FINAL de la barra: el útil, o el tope del preset si es más chico.
  final double anchoBarra;

  /// Relleno interno de la barra (contra los cantos de la barra, no de la
  /// pantalla).
  final double paddingInterno;

  const MiniplayerGeometria({
    required this.ladoCaratula,
    required this.radioCaratula,
    required this.margenLateral,
    required this.flotante,
    required this.conSombra,
    required this.factorIconos,
    required this.anchoDisponible,
    required this.anchoBarra,
    required this.paddingInterno,
  });

  /// Ancho que le queda a la barra una vez descontados los márgenes.
  double get anchoUtil => anchoDisponible - margenLateral * 2;

  /// ¿El tope del preset está haciendo algo? (entonces la barra va centrada).
  bool get conTope => anchoBarra < anchoUtil - 0.5;

  /// Margen lateral máximo: el 6% del ancho.
  static const _topeMargen = 0.06;

  /// Carátula máxima: el 22% del ancho.
  static const _topeCaratula = 0.22;

  /// Relleno interno de la barra, en proporción a la pantalla...
  static const _paddingPantalla = 0.04;

  /// ...pero jamás más de este porcentaje de la BARRA: si se acota el ancho, el
  /// relleno no puede seguir creciendo con una pantalla que ya no usa.
  static const _paddingBarra = 0.08;

  /// Piso del margen flotante: más cerca que esto se ve pegado y no flotante.
  static const _minMargen = 10.0;

  /// Piso de la carátula: por debajo de esto no se distingue la portada.
  static const _minCaratula = 24.0;

  /// Cálculo PURO: no lee nada del árbol, así se puede probar aparato por
  /// aparato sin montar la app.
  ///
  /// [baseCaratula], [baseRadioCaratula] y [baseMargen] son las medidas de HOY
  /// (las que ya trae el `Responsive` del aparato).
  factory MiniplayerGeometria.calcular({
    required TamanoMiniplayer tamano,
    required FormaMiniplayer forma,
    required bool esTv,
    required bool esEscritorio,
    required double anchoDisponible,
    required double baseCaratula,
    required double baseRadioCaratula,
    required double baseMargen,
    required double topeAncho,
  }) {
    // `auto` es la forma de SIEMPRE por aparato: en el celular pegada (si no,
    // queda un hueco contra la navbar) y en PC/TV flotante.
    final flotante =
        forma == FormaMiniplayer.auto
            ? (esTv || esEscritorio)
            : forma == FormaMiniplayer.flotante;

    final factor = tamano.factorCaratula;
    // El tipo va explícito: con la rama `0` (int) el ternario se infiere `num`
    // y después no entra en un campo `double`.
    final double margen =
        flotante
            ? _acotarArriba(
              baseMargen,
              _minMargen,
              anchoDisponible * _topeMargen,
            )
            : 0;
    // El tope es un MÁXIMO: si la pantalla es más angosta que el tope, no hace
    // nada (por eso en un monitor normal el preset de fábrica no cambia nada).
    final util = anchoDisponible - margen * 2;
    final anchoBarra = topeAncho > 0 && topeAncho < util ? topeAncho : util;
    // El redondeo del contenedor no entra acá: lo sigue eligiendo el usuario en
    // la tarjeta de Barras (y el cofre puede traerlo). Esto es sólo el tamaño.
    return MiniplayerGeometria(
      ladoCaratula: _acotarArriba(
        baseCaratula * factor,
        _minCaratula,
        anchoDisponible * _topeCaratula,
      ),
      radioCaratula: _acotarArriba(baseRadioCaratula * factor, 4, 20),
      margenLateral: margen,
      flotante: flotante,
      conSombra: flotante && !esTv,
      factorIconos: tamano.factorIconos,
      anchoDisponible: anchoDisponible,
      anchoBarra: anchoBarra,
      paddingInterno: _acotarArriba(
        anchoDisponible * _paddingPantalla,
        0,
        anchoBarra * _paddingBarra,
      ),

    );
  }

  /// Acota entre un piso y un techo que puede quedar POR DEBAJO del piso (una
  /// ventana más angosta que 2× el margen mínimo, por ejemplo). En ese caso
  /// manda el techo: en una pantalla así de chica cualquier margen es peor que
  /// el piso, y sin esta guarda el `clamp` de Dart tiraría una excepción.
  static double _acotarArriba(double valor, double min, double max) =>
      max <= min ? max : valor.clamp(min, max).toDouble();
}

/// La geometría que corresponde a este aparato y a las preferencias puestas.
MiniplayerGeometria geometriaMiniplayerDe(BuildContext context) {
  final r = Responsive(context);
  final p = AparienciaHelper.actual(context);
  return MiniplayerGeometria.calcular(
    tamano: p.tamanoMiniplayer,
    forma: p.formaMiniplayer,
    esTv: usarLayoutTv(context),
    esEscritorio: usarLayoutEscritorio(context),
    anchoDisponible: r.width,
    // Las medidas de HOY: el preset multiplica sobre esto, no lo pisa.
    baseCaratula: r.val(36, 32, 64),
    baseRadioCaratula: r.val(6, 5, 12),
    // La TV usa 22 fijo y la PC `sobre(18, 30)`, que en un monitor grande abre
    // un poco más. Se respeta tal cual: el default tiene que verse igual.
    baseMargen: usarLayoutTv(context) ? 22 : r.sobre(18, 30),
    topeAncho: p.anchoMiniplayer.tope,
  );
}
