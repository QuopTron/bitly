// ─────────────────────────────────────────────────────────────
// apariencia_barras_helper.dart — Acceso a las BARRAS: las esquinas de
// arriba del navbar y del miniplayer, el contorno que comparten y la
// PALETA del cofre con la que se tiñen.
//
// Va aparte de apariencia_helper.dart (el acceso base), de
// apariencia_espacios_helper.dart (cards y grillas) y de
// apariencia_paleta_helper.dart (la pintura del color) para que cada archivo
// haga una sola cosa: este es todo lo de Ajustes → Apariencia → Barras.
//
// La paleta se resuelve por el id guardado (catalogo_disenos_barra): la
// paleta de regalo no tiene colores, así la barra queda con el vidrio de
// siempre y abrir el cofre sin tocar nada no cambia la app.
//
// Se conecta con: apariencia_helper.dart (leer/cambiar las preferencias) +
// barra_navegacion_flotante + miniplayer + el cofre de Ajustes.
// Parte del flujo: presentación (navbar y miniplayer).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/modelos/usuario/catalogo_disenos_barra_lista.dart';
import '../../../core/modelos/usuario/preferencias_apariencia.dart';
import 'apariencia_helper.dart';

/// Barras: trazo, esquinas de arriba y paletas del cofre.
class AparienciaBarras {
  AparienciaBarras._();

  /// Trazo elegido para las barras (navbar/miniplayer).
  static TrazoBarra trazo(BuildContext context) =>
      AparienciaHelper.actual(context).trazoBarra;

  /// Opacidad y grosor del contorno según lo elegido. Con `sinTrazo`
  /// devuelve grosor 0: la barra no dibuja contorno.
  static (double opacidad, double grosor) trazoBorde(BuildContext context) =>
      bordeDe(trazo(context));

  /// Opacidad y grosor de un contorno cualquiera. Es puro (sin contextos)
  /// para que la MUESTRA de un diseño del cofre pueda pintar el contorno que
  /// ese diseño trae, no el que está puesto ahora.
  static (double opacidad, double grosor) bordeDe(TrazoBarra t) {
    switch (t) {
      case TrazoBarra.sinTrazo:
        return (0, 0);
      case TrazoBarra.suave:
        return (0.10, 0.5);
      case TrazoBarra.marcado:
        return (0.22, 1.0);
    }
  }

  /// Redondeo de las dos esquinas de ARRIBA del navbar.
  static double radioNavbar(BuildContext context) =>
      AparienciaHelper.actual(context).radioNavbar;

  /// Redondeo de las dos esquinas de ARRIBA del miniplayer.
  static double radioMiniplayer(BuildContext context) =>
      AparienciaHelper.actual(context).radioMiniplayer;

  /// Colores de la paleta en uso en una de las barras. Vacío = la paleta de
  /// regalo: la barra se ve con el vidrio de siempre, sin ningún tinte.
  static List<Color> paletaBarra(BuildContext context, {required bool navbar}) {
    final p = AparienciaHelper.actual(context);
    final d = disenoPorId(navbar ? p.disenoNavbarId : p.disenoMiniplayerId);
    return [for (final c in d?.paleta ?? const <int>[]) Color(c)];
  }

  /// Cambia el trazo del contorno de las barras.
  static void cambiarTrazo(BuildContext context, TrazoBarra trazo) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(trazoBarra: trazo),
      );

  /// Cambia el redondeo de las esquinas de arriba del navbar a mano (pasa a
  /// contar como "Personalizado": ya no coincide con ninguna paleta).
  static void cambiarRadioNavbar(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(
          radioNavbar: valor,
          disenoNavbarId: PreferenciasApariencia.disenoPersonalizado,
        ),
      );

  /// Cambia el redondeo de las esquinas de arriba del miniplayer a mano.
  static void cambiarRadioMiniplayer(BuildContext context, double valor) =>
      AparienciaHelper.cambiar(
        context,
        AparienciaHelper.actual(context).copiarCon(
          radioMiniplayer: valor,
          disenoMiniplayerId: PreferenciasApariencia.disenoPersonalizado,
        ),
      );

  /// Marca regalos como ya vistos (se llama al USAR una paleta del cofre: ahí
  /// es cuando el regalo se considera abierto). Baja el mininumerito.
  static void marcarRegalosVistos(BuildContext context, List<String> ids) {
    if (ids.isEmpty) return;
    final actuales =
        AparienciaHelper.actual(context).regalosVistos.toSet()..addAll(ids);
    AparienciaHelper.cambiar(
      context,
      AparienciaHelper.actual(
        context,
      ).copiarCon(regalosVistos: actuales.toList()),
    );
    if (AparienciaHelper.regalos.value > 0) {
      AparienciaHelper.regalos.value -= ids.length;
    }
    if (AparienciaHelper.regalos.value < 0) AparienciaHelper.regalos.value = 0;
  }
}
