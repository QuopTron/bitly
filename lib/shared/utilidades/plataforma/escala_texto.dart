// ─────────────────────────────────────────────────────────────
// escala_texto.dart — Límites de la escala de texto del sistema.
//
// Por qué existe: en Android el usuario puede subir el "tamaño de pantalla" o
// el "tamaño de fuente", y el sistema manda un textScaler bastante mayor a 1.
// La app está diseñada con tamaños fijos, así que con escalas grandes las cajas
// cambian de tamaño, las filas se desbordan y —lo peor— los botones de
// "Siguiente" del tutorial quedaban fuera de la tarjeta y el tutorial no se
// podía avanzar.
//
// Acá se acota UNA vez para toda la app: el texto sigue agrandándose (nada de
// ignorar la preferencia del usuario), pero nunca más allá de lo que el layout
// soporta. Es el mismo rango que usa el overlay del tutorial, así que la app y
// el tutorial coinciden.
//
// Se conecta con: app.dart (lo aplica a toda la UI) y
// features/tutorial_interactivo/overlay (lo aplica a la tarjeta del tutorial).
// Parte del flujo: presentación (escala de texto global).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Escala mínima aceptada. El sistema casi nunca baja de 1, pero una app
/// web/escritorio puede llegar con 0.8 y el texto quedaría ilegible.
const double escalaTextoMinima = 0.9;

/// Escala máxima: por encima de esto los diseños de tamaño fijo (tarjetas,
/// filas de botones, grillas) se desbordan y dejan botones fuera de alcance.
const double escalaTextoMaxima = 1.3;

/// Aplica [escalaTextoMinima]..[escalaTextoMaxima] al subárbol [child].
///
/// Se usa el mismo helper en toda la app para que no exista una vista con un
/// límite distinto (que es como se cuelan justamente los desbordes).
Widget acotarEscalaTexto({
  required BuildContext context,
  required Widget child,
}) {
  return MediaQuery.withClampedTextScaling(
    minScaleFactor: escalaTextoMinima,
    maxScaleFactor: escalaTextoMaxima,
    child: child,
  );
}
