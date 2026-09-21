// ─────────────────────────────────────────────────────────────
// catalogo_disenos_barra_lista.dart — La LISTA de diseños del cofre
// (navbar + miniplayer) y el contador de regalos.
//
// Va aparte del modelo (catalogo_disenos_barra.dart) para que cada
// archivo haga una sola cosa: uno describe QUÉ es un diseño y cuándo
// está abierto; este dice CUÁLES hay, CUÁLES le tocan a este aparato y
// cuántos regalos se pueden abrir ahora.
// Reexporta el modelo, así que alcanza con importar este archivo.
//
// El cofre mezcla TRES familias (ver los archivos de cada una):
//   FORMAS  → curvan las esquinas de arriba o cambian el contorno.
//   ADORNOS → el borde ondulado (olas) o una calcomanía encima.
//   COLORES → las paletas. No tocan la forma.
// Y cada familia puede traer diseños DE UN APARATO (ver
// catalogo_disenos_barra_aparatos): esos solo se muestran en la TV, la PC o
// el celular para el que se pensaron, así que este archivo es el que separa
// el catálogo por aparato ([disenosParaAparato] / [coloresParaAparato]).
// El PRIMERO es el regalo que trae la app (llega con la v1.0.0 y no toca
// nada): abrir el cofre sin elegir no cambia cómo se ve la app.
//
// Los nombres NO viven acá: son texto localizado (StringsCofrePaletas,
// que los resuelve por id). Acá solo hay forma, color, aparato y condiciones.
//
// Se conecta con: catalogo_disenos_barra.dart (el modelo) +
// catalogo_disenos_barra_formas / _adornos / _colores / _aparatos (las
// familias) + apariencia_helper (cuenta los regalos).
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

import 'catalogo_disenos_barra.dart';
import '../barra/catalogo_disenos_barra_adornos.dart';
import '../barra/catalogo_disenos_barra_aparatos.dart';
import '../barra/catalogo_disenos_barra_colores.dart';
import '../barra/catalogo_disenos_barra_desbloqueo.dart';
import '../barra/catalogo_disenos_barra_formas.dart';
import '../../dispositivos/dispositivo_conectado.dart';

export 'catalogo_disenos_barra.dart';
export '../barra/catalogo_disenos_barra_desbloqueo.dart';

/// Los DISEÑOS de forma y adorno, con el regalo de la app primero.
/// El cofre los muestra en su propia sección (los colores van aparte).
const List<DisenoBarra> disenosCofreBarra = [
  // El regalo que trae la app (v1.0.0): no toca ni forma ni color.
  DisenoBarra(id: 'paleta_regalo_100', llegoConVersion: '1.0.0'),
  ...disenosFormaBarra,
  ...disenosAdornoBarra,
  ...disenosFormaAparato,
];

/// Los COLORES del cofre: las paletas. Van en su propia sección.
const List<DisenoBarra> coloresCofreBarra = [
  ...disenosColorBarra,
  ...disenosColorAparato,
];

/// Catálogo completo, en el orden en que se muestra en el cofre.
const List<DisenoBarra> catalogoDisenosBarra = [
  ...disenosCofreBarra,
  ...coloresCofreBarra,
];

/// Los diseños que le tocan a [aparato]: los de todos los aparatos más los
/// suyos. Es lo que muestra la sección \"Diseños\" del cofre.
List<DisenoBarra> disenosParaAparato(TipoDispositivo aparato) =>
    disenosCofreBarra.where((d) => d.seVeEn(aparato)).toList(growable: false);

/// Los colores que le tocan a [aparato] (mismo criterio).
List<DisenoBarra> coloresParaAparato(TipoDispositivo aparato) =>
    coloresCofreBarra.where((d) => d.seVeEn(aparato)).toList(growable: false);

/// Ids del cofre viejo que ya no existen → el diseño que ocupa su lugar.
/// Así una preferencia ya guardada sigue mostrando \"En uso\" en el cofre en
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
/// marca de \"ajustado a mano\"). Los ids viejos heredan para no dejar la
/// barra sin dueño.
DisenoBarra? disenoPorId(String? id) {
  if (id == null || id.isEmpty) return null;
  final buscado = _herederos[id] ?? id;
  for (final d in catalogoDisenosBarra) {
    if (d.id == buscado) return d;
  }
  return null;
}

/// Regalos que el usuario PUEDE abrir ahora en [aparato] y todavía no vio: lo
/// que desbloqueó (por horas o por versión) y no está en [vistos]. Es el
/// número que se muestra en el mininumerito de Ajustes.
///
/// El filtro por aparato es a propósito: si contara los diseños de otro
/// aparato, el mininumerito quedaría encendido para siempre con algo que el
/// usuario nunca puede abrir donde está parado.
List<DisenoBarra> regalosDisponibles({
  required int horas,
  required int version,
  required Set<String> vistos,
  required TipoDispositivo aparato,
}) => catalogoDisenosBarra
    .where(
      (d) =>
          d.desbloqueo != DesbloqueoBarra.libre &&
          !vistos.contains(d.id) &&
          d.seVeEn(aparato) &&
          disenoDesbloqueado(d, horas: horas, version: version),
    )
    .toList(growable: false);
