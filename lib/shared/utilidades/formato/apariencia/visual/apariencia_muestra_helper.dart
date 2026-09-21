// ─────────────────────────────────────────────────────────────
// apariencia_muestra_helper.dart — Qué debe VERSE en la MUESTRA de un
// diseño del cofre: su adorno y su calcomanía.
//
// Va aparte de apariencia_disenos_helper.dart (que sabe aplicar y leer los
// diseños) para que cada archivo haga una sola cosa: este resuelve el caso de
// la tarjeta, donde un diseño que NO trae adorno tiene que mostrar el que ya
// está puesto (así mover el control se ve reflejado en el cofre).
//
// Se conecta con: apariencia_disenos_helper (le pasa el adorno puesto) +
// el cofre de Ajustes (la tarjeta de cada diseño).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../core/modelos/usuario/disenos/base/catalogo_disenos_barra_lista.dart';
import '../base/apariencia_disenos_helper.dart';

/// Adorno y calcomanía que muestra la tarjeta de un diseño.
class AparienciaMuestra {
  AparienciaMuestra._();

  /// Adorno de la muestra de [d]: el suyo, o el que ya está puesto.
  static AdornoBarra adorno(
    BuildContext context,
    DisenoBarra d, {
    required bool navbar,
  }) =>
      d.tieneAdorno
          ? d.adorno
          : AparienciaDisenos.adornoDe(context, navbar: navbar);

  /// Calcomanía de la muestra de [d]: la suya, o la que ya está puesta.
  static String sticker(
    BuildContext context,
    DisenoBarra d, {
    required bool navbar,
  }) =>
      d.tieneSticker
          ? d.sticker
          : AparienciaDisenos.stickerDe(context, navbar: navbar);
}
