// ─────────────────────────────────────────────────────────────
// puntero_tv_eventos.dart — Emisor de eventos de mouse del puntero
// de TV: emula hover, clic y scroll sobre la posición que le indique
// el llamador, para que los widgets respondan como si hubiera un
// mouse real.
// Se conecta con: puntero_tv_estado.dart (lo usa).
// Parte del flujo: entrada de usuario en TV.
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Traduce gestos del control remoto a eventos de mouse reales.
///
/// Es independiente del widget: recibe por constructor la posición
/// global a usar y cómo avisar a la UI, así puede vivir fuera del mixin.
class EmisorPunteroTv {
  EmisorPunteroTv({
    required this.posicionGlobal,
    required this.estaMontado,
    required void Function(VoidCallback) actualizarEstado,
  }) : _actualizarEstado = actualizarEstado;

  static const int idPuntero = 777;

  /// Devuelve la posición global actual del cursor (en píxeles de pantalla).
  final Offset Function() posicionGlobal;

  /// ¿El widget que lo usa sigue montado? (evita setState tras dispose).
  final bool Function() estaMontado;

  /// Avisa al widget para que repinte (equivalente a setState).
  final void Function(VoidCallback) _actualizarEstado;

  /// ¿Ya se anunció el puntero al motor de gestos?
  bool mouseAgregado = false;

  /// ¿El botón está apretado mientras corre el `PointerUp` diferido?
  bool presionando = false;

  void _enviar(PointerEvent evento) {
    try {
      WidgetsBinding.instance.handlePointerEvent(evento);
    } catch (e) {
      debugPrint("[PunteroTv] $e");
    }
  }

  /// Anuncia el cursor y manda un hover en la posición actual.
  void hover() {
    final g = posicionGlobal();
    if (!mouseAgregado) {
      mouseAgregado = true;
      _enviar(PointerAddedEvent(
        device: idPuntero,
        kind: PointerDeviceKind.mouse,
        position: g,
      ));
    }
    _enviar(PointerHoverEvent(
      device: idPuntero,
      kind: PointerDeviceKind.mouse,
      position: g,
      buttons: 0,
    ));
  }

  /// Emula un clic completo (down + up diferido) en la posición del cursor.
  ///
  /// La posición se CONGELA una sola vez y se usa para el tap completo. Si el
  /// up se enviara en otra coordenada (por ejemplo porque una flecha del D-pad
  /// movió el cursor entre ambos eventos, o porque el hover de un frame movió
  /// la vista), el motor de gestos vería un arrastre y CANCELARÍA el toque: el
  /// botón no se activaba o se activaba el vecino ("clic falso"). Congelada, el
  /// clic cae exactamente donde se ve el cursor.
  void clicar() {
    if (presionando) return;
    presionando = true;
    _actualizarEstado(() {});

    // Hover primero: posiciona el hit-test debajo del cursor.
    hover();
    final g = posicionGlobal();
    _enviar(PointerDownEvent(
      device: idPuntero,
      kind: PointerDeviceKind.mouse,
      position: g,
      buttons: kPrimaryButton,
    ));
    Timer(const Duration(milliseconds: 80), () {
      _enviar(PointerUpEvent(
        device: idPuntero,
        kind: PointerDeviceKind.mouse,
        position: g,
        buttons: 0,
      ));
      presionando = false;
      if (estaMontado()) _actualizarEstado(() {});
    });
  }

  /// Manda un scroll vertical en la posición actual del cursor.
  void desplazar(double dy) {
    hover();
    _enviar(PointerScrollEvent(
      device: idPuntero,
      kind: PointerDeviceKind.mouse,
      position: posicionGlobal(),
      scrollDelta: Offset(0, dy),
    ));
  }

  /// Retira el puntero (al desmontar el widget).
  void removed() {
    _enviar(PointerRemovedEvent(
      device: idPuntero,
      kind: PointerDeviceKind.mouse,
    ));
  }
}
