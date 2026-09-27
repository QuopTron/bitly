// ─────────────────────────────────────────────────────────────
// apariencia_espacios_helper.dart — Acceso a la SEPARACIÓN de las cards
// y las grillas, el redondeo de las cards y las líneas divisorias que
// aparecen cuando se pegan (modo "unido" tipo Spotify).
//
// Va aparte de apariencia_helper.dart (que guarda el acceso base a las
// preferencias) para que cada archivo haga una sola cosa: este es todo lo
// que se ajusta en Ajustes → Apariencia → Diseño.
//
// Lee del mismo notifier global, así tocar un control repinta al instante.
// Se conecta con: apariencia_helper.dart (leer/cambiar las preferencias) +
// las vistas con cards y grillas.
// Parte del flujo: presentación (espaciado de cards y grillas).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../base/apariencia_helper.dart';

/// Separación, redondeo y líneas de las cards y las grillas.
class AparienciaEspacios {
  AparienciaEspacios._();

  /// Separación horizontal GENERAL (promedio de los componentes).
  static double espacioX(BuildContext context) =>
      AparienciaHelper.actual(context).espacioX;

  /// Separación vertical GENERAL.
  static double espacioY(BuildContext context) =>
      AparienciaHelper.actual(context).espacioY;

  /// Separa el eje horizontal de las cards de CANCIÓN.
  static double espacioXCancion(BuildContext context) =>
      AparienciaHelper.actual(context).cancionX;

  /// Separa el eje vertical de las cards de canción.
  static double espacioYCancion(BuildContext context) =>
      AparienciaHelper.actual(context).cancionY;

  /// Separa el eje horizontal de las cards de GRILLA.
  static double espacioXGrilla(BuildContext context) =>
      AparienciaHelper.actual(context).grillaX;

  /// Separa el eje vertical de las cards de grilla.
  static double espacioYGrilla(BuildContext context) =>
      AparienciaHelper.actual(context).grillaY;

  /// ¿Los cuatro valores van iguales? (para el chip "Personalizado").
  static bool separacionUniforme(BuildContext context) =>
      AparienciaHelper.actual(context).separacionUniforme;

  /// Redondeo de las cards.
  static double radioCards(BuildContext context) =>
      AparienciaHelper.actual(context).radioCards;

  /// Multiplicador del TAMAÑO DE LAS LETRAS de toda la app.
  static double escalaTexto(BuildContext context) =>
      AparienciaHelper.actual(context).escalaTexto;

  /// Multiplicador del TAMAÑO DE LOS ICONOS de las piezas compartidas.
  static double escalaIconos(BuildContext context) =>
      AparienciaHelper.actual(context).escalaIconos;

  /// Opacidad de la línea que separa las filas de CANCIÓN.
  static double opacidadLineaYCancion(BuildContext context) =>
      AparienciaHelper.actual(context).opacidadLineaYCancion;

  /// Opacidad de la línea que separa las filas de la GRILLA.
  static double opacidadLineaYGrilla(BuildContext context) =>
      AparienciaHelper.actual(context).opacidadLineaYGrilla;

  /// Opacidad de la línea que separa las columnas de la GRILLA.
  static double opacidadLineaXGrilla(BuildContext context) =>
      AparienciaHelper.actual(context).opacidadLineaXGrilla;

  /// Opacidad "general" (vista previa de Ajustes).
  static double opacidadLineaY(BuildContext context) =>
      AparienciaHelper.actual(context).opacidadLineaY;

  /// Opacidad "general" del eje horizontal (vista previa de Ajustes).
  static double opacidadLineaX(BuildContext context) =>
      AparienciaHelper.actual(context).opacidadLineaX;

  /// Control GENERAL: mueve los cuatro valores (los dos componentes, los dos
  /// ejes) al mismo número.
  static void cambiarSeparacion(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(
          context,
        ).copiarCon(espacioX: valor, espacioY: valor),
      );

  /// Cambia la separación horizontal de los DOS componentes.
  static void cambiarEspacioX(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(espacioX: valor),
      );

  /// Afina el eje horizontal de las cards de canción.
  static void cambiarCancionX(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(cancionX: valor),
      );

  /// Afina el eje vertical de las cards de canción.
  static void cambiarCancionY(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(cancionY: valor),
      );

  /// Afina el eje horizontal de las cards de grilla.
  static void cambiarGrillaX(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(grillaX: valor),
      );

  /// Afina el eje vertical de las cards de grilla.
  static void cambiarGrillaY(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(grillaY: valor),
      );

  /// Cambia el redondeo de las cards.
  static void cambiarRadio(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(radioCards: valor),
      );

  /// Cambia el tamaño de las letras de la app.
  static void cambiarEscalaTexto(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(escalaTexto: valor),
      );

  /// Cambia el tamaño de los iconos de las piezas compartidas.
  static void cambiarEscalaIconos(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(escalaIconos: valor),
      );

  /// Cambia SOLO el tamaño de los títulos de las tarjetas.
  static void cambiarEscalaTitulos(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(escalaTitulos: valor),
      );

  /// Cambia SOLO el tamaño de los textos secundarios.
  static void cambiarEscalaTextos(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(escalaTextos: valor),
      );

  /// Cambia SOLO el tamaño de los iconos de las tarjetas.
  static void cambiarEscalaIconosCards(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(escalaIconosCards: valor),
      );

  /// Cambia SOLO el tamaño de los iconos de las barras (navbar y miniplayer).
  static void cambiarEscalaIconosBarras(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(escalaIconosBarras: valor),
      );
}
