// ─────────────────────────────────────────────────────────────
// grilla_vista.dart — Cuántas columnas tiene una grilla de tarjetas.
//
// Por qué existe: la misma cuenta (2 en un celular, 3 en una tablet, 4 en una
// PC y 6 en una pantalla grande) estaba COPIADA igual en tres grillas —feed,
// búsqueda y mi espacio—. Tres copias de la misma fórmula es la forma más
// segura de que dos queden viejas: mover un umbral obligaba a acordarse de los
// tres archivos.
//
// Acá vive UNA vez. Y encima respeta el tope de columnas que el usuario le puso
// a esa VISTA (Ajustes → Apariencia → Vistas), que es lo que hace que el eje
// tenga un consumidor de verdad en vez de un control que no hace nada:
//
//     columnas de la vista  →  lo que pide el ancho  →  fábrica
//
// El tope sólo puede REDUCIR. Pedirle más columnas a un celular de 340 px no
// daría portadas más grandes sino portadas del tamaño de un sello.
//
// Se conecta con: ambito_vista.dart (el tope de la vista) + las 3 grillas.
// Parte del flujo: presentación (grillas de feed, búsqueda y mi espacio).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../widgets/vista/base/ambito_vista.dart';

/// Columnas que le corresponden a una grilla con [disponible] píxeles lógicos
/// de ancho, ya con el tope de la vista aplicado.
///
/// [disponible] tiene que ser el ancho REAL del hueco de la grilla (lo que
/// queda después del padding), no el de la pantalla: en la PC la barra lateral
/// se come un pedazo y la cuenta quedaría con una columna de más.
int columnasDeGrilla(BuildContext context, double disponible) {
  var columnas = 2;
  if (disponible > 1000) {
    columnas = 6;
  } else if (disponible > 700) {
    columnas = 4;
  } else if (disponible > 340) {
    columnas = 3;
  }
  final tope = AmbitoVista.columnasDe(context);
  // 0 = automático (sin tope). Un tope mayor que lo que pide el ancho no
  // inventa columnas: el ancho manda.
  if (tope <= 0 || tope >= columnas) return columnas;
  return tope;
}
