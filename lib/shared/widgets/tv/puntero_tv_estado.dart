// ─────────────────────────────────────────────────────────────
// puntero_tv_estado.dart — Estado del puntero de TV.
//
// Qué hace: maneja el teclado del control remoto (flechas del D-pad,
// OK/Enter para clic, Canal+/- para scroll) y mueve el cursor con
// aceleración al mantener. La emulación de eventos de mouse vive en
// puntero_tv_eventos.dart.
//
// Regla clave: MOVER el cursor es puramente visual (no se inyecta hover),
// para que la capa de atrás no reaccione al desplazamiento. Con las flechas
// NADA llega al árbol salvo la pulsación real (y la rueda).
//
// También SIGUE al mouse real (control con giroscopio / air mouse):
// esos controles mandan eventos de mouse de verdad, así que si el
// cursor dibujado se quedaba en otro lado, el clic del control caía
// sobre otra tarjeta (el "clic falso" al mover el puntero).
//
// Con el mouse REAL el hover se deja pasar a propósito: es del sistema, sigue
// al puntero físico y es la única señal que trae el movimiento sin botones
// (imprescindible para el seguimiento de arriba). Marca lo que hay debajo,
// pero nunca activa: eso fija test/unit/puntero_tv_sin_hover_test.dart.
//
// Además el estado recuerda SI el usuario viene manejándose con un mouse/air
// mouse real (`usandoMouseReal`): en ese caso la TV ya dibuja su propio cursor
// del sistema y el aro propio se esconde para no ver DOS flechas. La marca se
// prende en `adoptarPunteroReal` (único lugar donde se ven eventos de mouse de
// verdad) y se apaga apenas se usa el D-pad, que es cuando el aro vuelve a ser
// la única referencia de dónde se está parado.
//
// Se conecta con: puntero_tv.dart (monta este estado) +
// puntero_tv_eventos.dart.
// Parte del flujo: entrada de usuario en TV.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'puntero_tv_eventos.dart';

/// Estado del puntero de TV: keyboard + mouse emulation.
mixin PunteroTvEstado<T extends StatefulWidget> on State<T> {
  static const double _paso = 24;
  static const double _pasoScroll = 120;
  static const double _margenBorde = 0.5;

  @protected
  Offset posCursor = Offset.zero;
  @protected
  bool posicionadoCursor = false;
  DateTime? _ultimaTecla;
  int _repeticion = 0;

  /// ¿El usuario viene manejándose con un mouse/air mouse REAL?
  ///
  /// Si es así, la TV ya muestra el cursor del sistema en la posición del
  /// puntero físico, así que el aro dibujado se esconde (ver `PunteroTv.build`)
  /// para no ver dos cursores. Al tocar cualquier tecla del control (D-pad) se
  /// apaga y el aro vuelve, porque ahí el control remoto es la única forma de
  /// saber dónde se está parado.
  bool _usandoMouseReal = false;

  late final EmisorPunteroTv _emisor = EmisorPunteroTv(
    posicionGlobal: () => _global(posCursor),
    estaMontado: () => mounted,
    actualizarEstado: (fn) => setState(fn),
  );

  /// ¿El botón está apretado? (lo lee la capa visual del cursor).
  @protected
  bool get presionandoCursor => _emisor.presionando;

  /// ¿Ya se anunció el puntero al motor de gestos?
  @protected
  bool get mouseAgregado => _emisor.mouseAgregado;

  /// ¿El puntero que se está usando es un mouse/air mouse real?
  ///
  /// Lo lee la capa visual: con mouse real el aro propio se oculta (doble
  /// cursor), con D-pad se muestra.
  @protected
  bool get usandoMouseReal => _usandoMouseReal;

  /// Marca que la entrada viene del D-pad (control remoto) y no del mouse.
  ///
  /// Apenas se toca una tecla del control el aro dibujado vuelve a mostrarse:
  /// con el D-pad es la única referencia que tiene el usuario.
  void _usarDpad() {
    if (!_usandoMouseReal) return;
    setState(() => _usandoMouseReal = false);
  }

  RenderBox? get _caja {
    final ro = context.findRenderObject();
    return ro is RenderBox && ro.hasSize ? ro : null;
  }

  Size get _tamano => _caja?.size ?? MediaQuery.sizeOf(context);

  @protected
  Offset centro() {
    final t = _tamano;
    return Offset(t.width / 2, t.height / 2);
  }

  Offset _global(Offset local) {
    final caja = _caja;
    if (caja == null) return local;
    return caja.localToGlobal(local);
  }

  Offset? _deltaDe(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return const Offset(0, -_paso);
    if (key == LogicalKeyboardKey.arrowDown) return const Offset(0, _paso);
    if (key == LogicalKeyboardKey.arrowLeft) return const Offset(-_paso, 0);
    if (key == LogicalKeyboardKey.arrowRight) return const Offset(_paso, 0);
    return null;
  }

  double? _scrollDe(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.channelDown) {
      return _pasoScroll;
    }
    if (key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.channelUp) {
      return -_pasoScroll;
    }
    return null;
  }

  bool _esClic(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.space;
  }

  /// Sigue al mouse REAL (air mouse): el cursor dibujado se pone donde el
  /// control tiene su puntero, así el clic cae donde el usuario lo ve.
  ///
  /// Los eventos que emite este mismo puntero se ignoran: si no, se
  /// realimentaría consigo mismo.
  void adoptarPunteroReal(PointerEvent evento) {
    if (!mounted) return;
    if (evento.device == EmisorPunteroTv.idPuntero) return;
    if (evento.kind != PointerDeviceKind.mouse &&
        evento.kind != PointerDeviceKind.trackpad) {
      return;
    }
    final local = _local(evento.position);
    final t = _tamano;
    setState(() {
      posCursor = Offset(
        local.dx.clamp(_margenBorde, t.width - _margenBorde),
        local.dy.clamp(_margenBorde, t.height - _margenBorde),
      );
      posicionadoCursor = true;
      // Hay un mouse real en uso: la tele ya dibuja su cursor, así que el aro
      // propio se esconde (si no, se ven dos flechas al mismo tiempo).
      _usandoMouseReal = true;
    });
  }

  /// Pasa una posición global a coordenadas del lienzo del puntero.
  Offset _local(Offset global) {
    final caja = _caja;
    if (caja == null) return global;
    return caja.globalToLocal(global);
  }

  /// Handler principal del teclado.
  bool alTeclado(KeyEvent evento) {
    if (!mounted) return false;
    final key = evento.logicalKey;

    final delta = _deltaDe(key);
    if (delta != null) {
      if (evento is KeyUpEvent) {
        _repeticion = 0;
        _ultimaTecla = null;
      } else {
        _usarDpad();
        _mover(delta);
      }
      return true;
    }

    if (_esClic(key)) {
      if (evento is KeyDownEvent) {
        _usarDpad();
        _emisor.clicar();
      }
      return true;
    }

    final scroll = _scrollDe(key);
    if (scroll != null) {
      if (evento is! KeyUpEvent) {
        _usarDpad();
        _emisor.desplazar(scroll);
      }
      return true;
    }

    return false;
  }

  void _mover(Offset delta) {
    final ahora = DateTime.now();
    final seguido =
        _ultimaTecla != null &&
        ahora.difference(_ultimaTecla!).inMilliseconds < 600;
    _repeticion = seguido ? (_repeticion + 1).clamp(0, 20) : 0;
    _ultimaTecla = ahora;

    final factor = 1 + _repeticion * 0.16;
    final t = _tamano;
    final nueva = Offset(
      (posCursor.dx + delta.dx * factor).clamp(
        _margenBorde,
        t.width - _margenBorde,
      ),
      (posCursor.dy + delta.dy * factor).clamp(
        _margenBorde,
        t.height - _margenBorde,
      ),
    );
    setState(() => posCursor = nueva);
    // A propósito NO se manda hover al mover.
    //
    // Antes sí se mandaba y en la tele se veía como si la capa de atrás
    // "también se moviera": cada flecha iluminaba con hover la card o el botón
    // que quedaban debajo del cursor (el InkWell de las tarjetas, los
    // MouseRegion), así que al desplazarse parecía que saltaba de una tarjeta a
    // otra y, cuando se acababan, a un ícono. Ese es el "clic falso"
    // reportado. El cursor dibujado ya muestra dónde estás parado, así que la
    // capa de atrás no necesita reaccionar al movimiento: el hover se reserva
    // para el clic real (ver `clicar()`), donde además posiciona el hit-test.
  }

  /// Inicializa posición y handler de teclado.
  void initPuntero() {
    posCursor = centro();
    posicionadoCursor = true;
    HardwareKeyboard.instance.addHandler(alTeclado);
  }

  @protected
  void enviarPointerRemoved() => _emisor.removed();
}
