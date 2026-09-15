// ─────────────────────────────────────────────────────────────
// puntero_tv.dart — Puntero virtual para TV (Android TV / Google TV / Fire TV).
//
// Por qué existe: la app está diseñada para el dedo, y en TV el control remoto
// solo manda flechas. Sin puntero, el usuario queda encerrado.
//
// Qué hace: dibuja un cursor y lo maneja con el control remoto.
//   - Flechas del D-pad  → mueven el cursor (con aceleración al mantener).
//   - OK / Enter / Space → clic EN LA POSICIÓN del cursor.
//   - Canal +/- / PageUp/Down → scroll de rueda en esa posición.
//
// StackFit.expand es obligatorio: con loose el FittedBox del viewport de TV
// no escalaba y el clic caía fuera del contenido.
//
// Se conecta con: app.dart (lo monta solo cuando esSmartTV).
// Parte del flujo: entrada de usuario en TV.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'puntero_tv_cursor.dart';
import 'puntero_tv_estado.dart';

/// Envuelve [child] con un puntero manejable por control remoto.
class PunteroTv extends StatefulWidget {
  final Widget child;
  static const double radio = 13;
  static const Key claveCursor = Key('bitly-puntero-tv-cursor');

  const PunteroTv({super.key, required this.child});

  @override
  State<PunteroTv> createState() => _PunteroTvState();
}

class _PunteroTvState extends State<PunteroTv> with PunteroTvEstado<PunteroTv> {
  bool _handlerRegistrado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_handlerRegistrado) {
      _handlerRegistrado = true;
      posCursor = centro();
      posicionadoCursor = true;
      HardwareKeyboard.instance.addHandler(alTeclado);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(alTeclado);
    if (mouseAgregado) {
      enviarPointerRemoved();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: posCursor.dx - PunteroTv.radio,
          top: posCursor.dy - PunteroTv.radio,
          child: IgnorePointer(
            child: CursorTv(
              key: PunteroTv.claveCursor,
              presionando: presionandoCursor,
            ),
          ),
        ),
      ],
    );
  }
}
