// ─────────────────────────────────────────────────────────────
// apariencia_disenos_helper.dart — Leer y APLICAR los DISEÑOS del cofre
// (Ajustes → Apariencia → Barras) sobre el navbar y el miniplayer.
//
// Va aparte de apariencia_barras_helper.dart (que resuelve el trazo, las
// esquinas y el color de una barra) para que cada archivo haga una sola cosa:
// este sabe qué toca cada diseño del catálogo, incluido el hecho de que un
// diseño puede traer SOLO forma, SOLO color o las dos cosas.
//
// Se conecta con: apariencia_barras_helper.dart (leer el color y el trazo) +
// apariencia_helper.dart (leer/cambiar las preferencias) +
// catalogo_disenos_barra_lista.dart (qué trae cada diseño).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/modelos/usuario/catalogo_disenos_barra_lista.dart';
// AdornoBarra vive en el modelo y se reexporta desde la lista.

import '../../../core/modelos/usuario/preferencias_apariencia.dart';
import 'apariencia_barras_helper.dart';
import 'apariencia_helper.dart';

/// Diseños del cofre: cuánto dejan puesto y cómo se aplican.
class AparienciaDisenos {
  AparienciaDisenos._();

  /// Radio de las esquinas de arriba que deja [d] en la barra elegida.
  /// Si el diseño no trae forma, devuelve la que ya está puesta.
  static double radioDe(
    BuildContext context,
    DisenoBarra d, {
    required bool navbar,
  }) {
    final p = AparienciaHelper.actual(context);
    final actual = navbar ? p.radioNavbar : p.radioMiniplayer;
    return d.radioArriba ?? actual;
  }

  /// Contorno que deja [d] (el suyo, o el que ya está puesto si no trae).
  static TrazoBarra trazoDe(BuildContext context, DisenoBarra d) =>
      d.trazo ?? AparienciaBarras.trazo(context);

  /// Id del diseño de ADORNO puesto en esa barra.
  static String _adornoId(BuildContext context, {required bool navbar}) {
    final p = AparienciaHelper.actual(context);
    return navbar ? p.adornoNavbarId : p.adornoMiniplayerId;
  }

  /// El adorno (esquinas u olas) que tiene puesta esa barra.
  static AdornoBarra adornoDe(BuildContext context, {required bool navbar}) {
    final d = disenoPorId(_adornoId(context, navbar: navbar));
    return d?.adorno ?? AdornoBarra.esquinas;
  }

  /// Id de la calcomanía que tiene puesta esa barra ('' = ninguna).
  static String stickerDe(BuildContext context, {required bool navbar}) {
    final d = disenoPorId(_adornoId(context, navbar: navbar));
    return d?.sticker ?? '';
  }

  /// Cuántas olas dibuja esa barra (de 2 a 6).
  static int olasDe(BuildContext context, {required bool navbar}) {
    final p = AparienciaHelper.actual(context);
    final i = navbar ? p.olasNavbar : p.olasMiniplayer;
    return PreferenciasApariencia.olasDe(i);
  }

  /// Intensidad CRUDA de las olas (0 a 1): es lo que mueve el control.
  static double intensidadOlas(BuildContext context, {required bool navbar}) {
    final p = AparienciaHelper.actual(context);
    return navbar ? p.olasNavbar : p.olasMiniplayer;
  }

  /// ¿Este diseño es el que está puesto en esa barra?
  ///
  /// Se compara el ESTADO real, no el id guardado: así una paleta y una forma
  /// conviven (podés tener "Aurora" de color y "Pastilla" de forma), y el
  /// regalo de la app cuenta como puesto cuando la barra está de fábrica.
  static bool disenoEnUso(
    BuildContext context,
    DisenoBarra d, {
    required bool navbar,
  }) {
    final p = AparienciaHelper.actual(context);
    final id = navbar ? p.disenoNavbarId : p.disenoMiniplayerId;
    final radio = navbar ? p.radioNavbar : p.radioMiniplayer;
    final deFabrica = PreferenciasApariencia.deFabrica;
    final radioFabrica =
        navbar ? deFabrica.radioNavbar : deFabrica.radioMiniplayer;
    final puesta = AparienciaBarras.paletaBarra(context, navbar: navbar);
    // El regalo que trae la app: puesto cuando no hay ni color, ni forma, ni
    // adorno tocados (es el estado de fábrica de la barra).
    if (!d.traeAlgo) {
      return puesta.isEmpty &&
          p.trazoBarra == deFabrica.trazoBarra &&
          (radio - radioFabrica).abs() < 0.01 &&
          _adornoId(context, navbar: navbar) == deFabrica.adornoNavbarId;
    }
    if (d.tienePaleta && id == d.id) return true;
    if (d.tieneForma && (radio - d.radioArriba!).abs() < 0.01) return true;
    if (d.tieneTrazo && p.trazoBarra == d.trazo) return true;
    if ((d.tieneAdorno || d.tieneSticker) &&
        _adornoId(context, navbar: navbar) == d.id) {
      return true;
    }
    return false;
  }

  /// Aplica un diseño del cofre a una de las dos barras. Cada diseño toca SOLO
  /// lo que trae: uno de forma cambia las esquinas de arriba (y su contorno)
  /// sin borrar el color que ya tenías, y una paleta tiñe la barra sin
  /// cambiarle la forma. Así forma y color se combinan.
  static void aplicarDiseno(
    BuildContext context,
    DisenoBarra d, {
    required bool navbar,
  }) {
    var p = AparienciaHelper.actual(context);
    if (d.tieneForma) {
      p =
          navbar
              ? p.copiarCon(
                radioNavbar: d.radioArriba,
                disenoNavbarId: PreferenciasApariencia.disenoPersonalizado,
              )
              : p.copiarCon(
                radioMiniplayer: d.radioArriba,
                disenoMiniplayerId: PreferenciasApariencia.disenoPersonalizado,
              );
    }
    if (d.tieneTrazo) p = p.copiarCon(trazoBarra: d.trazo);
    if (d.tieneAdorno || d.tieneSticker) {
      p =
          navbar
              ? p.copiarCon(adornoNavbarId: d.id)
              : p.copiarCon(adornoMiniplayerId: d.id);
    }
    if (d.tienePaleta) {
      p =
          navbar
              ? p.copiarCon(disenoNavbarId: d.id)
              : p.copiarCon(disenoMiniplayerId: d.id);
    }
    AparienciaHelper.cambiar(context, p);
  }
}
