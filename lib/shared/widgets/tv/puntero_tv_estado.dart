// ─────────────────────────────────────────────────────────────
// puntero_tv_estado.dart — Estado del puntero de TV.
//
// Qué hace: maneja el teclado del control remoto (flechas del D-pad,
// OK/Enter para clic, Canal+/- para scroll) y mueve el cursor con
// aceleración al mantener. La emulación de eventos de mouse vive en
// puntero_tv_eventos.dart.
//
// Se conecta con: puntero_tv.dart (monta este estado) +
// puntero_tv_eventos.dart.
// Parte del flujo: entrada de usuario en TV.
// ─────────────────────────────────────────────────────────────

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
        _mover(delta);
      }
      return true;
    }

    if (_esClic(key)) {
      if (evento is KeyDownEvent) _emisor.clicar();
      return true;
    }

    final scroll = _scrollDe(key);
    if (scroll != null) {
      if (evento is! KeyUpEvent) _emisor.desplazar(scroll);
      return true;
    }

    return false;
  }

  void _mover(Offset delta) {
    final ahora = DateTime.now();
    final seguido = _ultimaTecla != null &&
        ahora.difference(_ultimaTecla!).inMilliseconds < 600;
    _repeticion = seguido ? (_repeticion + 1).clamp(0, 20) : 0;
    _ultimaTecla = ahora;

    final factor = 1 + _repeticion * 0.16;
    final t = _tamano;
    final nueva = Offset(
      (posCursor.dx + delta.dx * factor)
          .clamp(_margenBorde, t.width - _margenBorde),
      (posCursor.dy + delta.dy * factor)
          .clamp(_margenBorde, t.height - _margenBorde),
    );
    setState(() => posCursor = nueva);
    _emisor.hover();
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
