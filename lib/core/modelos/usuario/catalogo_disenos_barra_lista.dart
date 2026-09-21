// ─────────────────────────────────────────────────────────────
// catalogo_disenos_barra_lista.dart — La LISTA de diseños del cofre
// (navbar + miniplayer) y el contador de regalos.
//
// Va aparte del modelo (catalogo_disenos_barra.dart) para que cada
// archivo haga una sola cosa: uno describe QUÉ es un diseño y cuándo
// está abierto; este dice CUÁLES hay y cuántos se pueden abrir ahora.
// Reexporta el modelo, así que alcanza con importar este archivo.
//
// El cofre mezcla TRES familias (ver los archivos de cada una):
//   FORMAS  → curvan las esquinas de arriba o cambian el contorno.
//   ADORNOS → el borde ondulado (olas) o una calcomanía encima.
//   COLORES → las paletas. No tocan la forma.
// El PRIMERO es el regalo que trae la app (llega con la v1.0.0 y no toca
// nada): abrir el cofre sin elegir no cambia cómo se ve la app.
//
// Los nombres NO viven acá: son texto localizado (StringsCofrePaletas,
// que los resuelve por id). Acá solo hay forma, color y condiciones.
//
// Se conecta con: catalogo_disenos_barra.dart (el modelo) +
// catalogo_disenos_barra_formas / _colores (las dos familias) +
// apariencia_helper (cuenta los regalos).
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

import 'catalogo_disenos_barra.dart';
import 'catalogo_disenos_barra_adornos.dart';
import 'catalogo_disenos_barra_colores.dart';
import 'catalogo_disenos_barra_desbloqueo.dart';
import 'catalogo_disenos_barra_formas.dart';

export 'catalogo_disenos_barra.dart';
export 'catalogo_disenos_barra_desbloqueo.dart';

/// Los DISEÑOS de forma y adorno, con el regalo de la app primero.
/// El cofre los muestra en su propia sección (los colores van aparte).
const List<DisenoBarra> disenosCofreBarra = [
  // El regalo que trae la app (v1.0.0): no toca ni forma ni color.
  DisenoBarra(id: 'paleta_regalo_100', llegoConVersion: '1.0.0'),
  ...disenosFormaBarra,
  ...disenosAdornoBarra,
];

/// Los COLORES del cofre: las paletas. Van en su propia sección.
const List<DisenoBarra> coloresCofreBarra = disenosColorBarra;

/// Catálogo completo, en el orden en que se muestra en el cofre.
const List<DisenoBarra> catalogoDisenosBarra = [
  ...disenosCofreBarra,
  ...coloresCofreBarra,
];

/// Ids del cofre viejo que ya no existen → el diseño que ocupa su lugar.
/// Así una preferencia ya guardada sigue mostrando "En uso" en el cofre en
/// vez de quedar sin dueño. Los ids de forma que SÍ existen (esquinas_rectas,
/// pastilla, muy_redondeada, filosa, sin_contorno, contorno_marcado) no van
/// acá: se resuelven solos y conservan su forma.
const Map<String, String> _herederos = {
  'fabrica_navbar': 'paleta_regalo_100',
  'fabrica_mini': 'paleta_regalo_100',
  'vitrea': 'paleta_regalo_100',
  'regalo_0922': 'paleta_regalo_100',
  'esquinas_doradas': 'paleta_oro',
};

/// El diseño del catálogo con ese id (null si no existe o si el id es la
/// marca de "ajustado a mano"). Los ids viejos heredan para no dejar la
/// barra sin dueño.
DisenoBarra? disenoPorId(String? id) {
  if (id == null || id.isEmpty) return null;
  final buscado = _herederos[id] ?? id;
  for (final d in catalogoDisenosBarra) {
    if (d.id == buscado) return d;
  }
  return null;
}

/// Regalos que el usuario PUEDE abrir ahora y todavía no vio: lo que
/// desbloqueó (por horas o por versión) y no está en [vistos]. Es el número
/// que se muestra en el mininumerito de Ajustes.
List<DisenoBarra> regalosDisponibles({
  required int horas,
  required int version,
  required Set<String> vistos,
}) => catalogoDisenosBarra
    .where(
      (d) =>
          d.desbloqueo != DesbloqueoBarra.libre &&
          !vistos.contains(d.id) &&
          disenoDesbloqueado(d, horas: horas, version: version),
    )
    .toList(growable: false);
