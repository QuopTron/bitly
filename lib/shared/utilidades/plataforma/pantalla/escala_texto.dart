// ─────────────────────────────────────────────────────────────
// escala_texto.dart — Protección global de layout contra la densidad y el
// tamaño de fuente del sistema.
//
// Por qué existe: en Android el usuario puede tocar dos ajustes que rompen un
// diseño pensado para "un celular normal":
//
//   1. Accesibilidad → Tamaño de fuente: el sistema manda un textScaler mayor
//      a 1. Las cajas cambian de tamaño, las filas se desbordan y —lo peor— los
//      botones de "Continuar"/"Siguiente" (setup y tutorial) quedaban fuera de
//      la tarjeta, así que el usuario no podía avanzar.
//   2. Pantalla → Tamaño de pantalla: sube la densidad, así que el MISMO
//      teléfono reporta MENOS px lógicos (un 360dp puede pasar a ~320). Un
//      layout de 3 columnas o una fila de botones deja de entrar.
//
// Qué hace [protegerLayout]: acota la escala de texto a un rango usable y, si
// el ancho lógico quedó por debajo del mínimo soportado, escala TODA la UI para
// que entre sin desbordar. El diseño no cambia: nada más no se rompe.
//
// Además de proteger el layout, acá se aplica el TAMAÑO DE LETRA elegido en
// Ajustes → Apariencia (ver escala_ui.dart): multiplica al del sistema, así que
// respeta la accesibilidad del teléfono en vez de pisarla.
//
// Se conecta con: app.dart (lo aplica a TODAS las pantallas, setup incluido),
// escala_ui (la preferencia del usuario) y
// features/tutorial_interactivo/overlay (acota además su propia tarjeta).
// Parte del flujo: presentación (protección de layout global).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'escala_ui.dart';

/// Escala mínima aceptada. El sistema casi nunca baja de 1, pero una app
/// web/escritorio puede llegar con 0.8 y el texto quedaría ilegible.
const double escalaTextoMinima = 0.9;

/// Escala máxima: por encima de esto los diseños de tamaño fijo (tarjetas,
/// filas de botones, grillas) se desbordan y dejan botones fuera de alcance.
const double escalaTextoMaxima = 1.3;

/// Tamaño de referencia para traducir el escalador del sistema (que puede ser
/// no lineal) a un factor único: "cuántas veces el tamaño de un texto de 14".
const double _tamanoReferencia = 14;

/// Techo ABSOLUTO de la escala de texto: el del sistema (1.3) multiplicado por
/// el máximo que puede elegir el usuario en Apariencia (1.4). Se acota acá
/// también para que ni la combinación de los dos rompa el layout.
const double escalaTextoMaximaAbsoluta = escalaTextoMaxima * 1.4;

/// Ancho lógico mínimo que sabe soportar el diseño (el de un celular chico
/// estándar). Por debajo de esto se escala la UI en vez de dejar que se
/// desborde: es lo que pasa cuando el usuario sube el "tamaño de pantalla".
const double anchoLogicoMinimo = 320;

/// Aplica [escalaTextoMinima]..[escalaTextoMaxima] al subárbol [child].
///
/// Se usa el mismo helper en toda la app para que no exista una vista con un
/// límite distinto (que es como se cuelan justamente los desbordes).
Widget acotarEscalaTexto({
  required BuildContext context,
  required Widget child,
}) {
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: _escalaAcotada(context)),
    child: child,
  );
}

/// Escala de texto final del árbol: la del SISTEMA (acotada) multiplicada por
/// la que eligió el usuario en Ajustes → Apariencia.
///
/// Por qué se multiplican y no se pisa una a la otra: si el usuario subió el
/// tamaño de fuente del teléfono (accesibilidad) y además elige 1.2 en la app,
/// lo que espera es "un poco más grande que como lo dejó", no perder su ajuste
/// del sistema. El resultado se acota al techo absoluto para que la suma de los
/// dos nunca desborde los diseños de tamaño fijo.
TextScaler _escalaAcotada(BuildContext context) {
  final sistema = MediaQuery.textScalerOf(
    context,
  ).clamp(minScaleFactor: escalaTextoMinima, maxScaleFactor: escalaTextoMaxima);
  final usuario = EscalaUi.texto.value;
  // Sin preferencia (lo normal), se devuelve EXACTAMENTE el escalador del
  // sistema: ni una vista cambia por tener esta función en el medio.
  if ((usuario - 1).abs() < 0.001) return sistema;

  final factor =
      (sistema.scale(_tamanoReferencia) / _tamanoReferencia) * usuario;
  return TextScaler.linear(
    factor.clamp(escalaTextoMinima, escalaTextoMaximaAbsoluta),
  );
}

/// Protege TODO el árbol [child] contra la densidad y el tamaño de fuente del
/// sistema. Se aplica una sola vez, en el `builder` de MaterialApp, así que
/// vale para todas las pantallas (setup, home, reproductor, ajustes, modales)
/// sin que ninguna tenga que acordarse.
Widget protegerLayout({required BuildContext context, required Widget child}) {
  final mq = MediaQuery.of(context);
  final conEscala = mq.copyWith(textScaler: _escalaAcotada(context));

  final ancho = conEscala.size.width;
  // Caso normal (cualquier celular de hoy): nada que escalar.
  if (!ancho.isFinite || ancho >= anchoLogicoMinimo) {
    return MediaQuery(data: conEscala, child: child);
  }

  // Densidad agresiva: se le presenta a la app un ancho de diseño y se escala
  // el resultado para que entre en la pantalla real. El layout se dibuja
  // pequeño pero completo — nunca recortado ni desbordado.
  final factor = ancho / anchoLogicoMinimo;
  final alto = conEscala.size.height / factor;
  return MediaQuery(
    data: conEscala.copyWith(size: Size(anchoLogicoMinimo, alto)),
    child: ClipRect(
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topLeft,
        child: SizedBox(width: anchoLogicoMinimo, height: alto, child: child),
      ),
    ),
  );
}
