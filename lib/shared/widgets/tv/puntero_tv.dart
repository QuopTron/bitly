// ─────────────────────────────────────────────────────────────
// puntero_tv.dart — Puntero virtual para TV (Android TV / Google TV / Fire TV).
//
// Por qué existe: la app está diseñada para el dedo, y en TV el control remoto
// solo manda flechas. Sin puntero, el usuario queda encerrado.
//
// Qué hace: dibuja un cursor y lo maneja con el control remoto.
//   - Flechas del D-pad  → mueven el cursor (con aceleración al mantener).
//                          Mover es SOLO visual: no se inyecta hover, así la
//                          capa de atrás (cards, íconos) no se resalta ni
//                          "se mueve" por el simple desplazamiento.
//   - OK / Enter / Space → clic EN LA POSICIÓN del cursor.
//   - Canal +/- / PageUp/Down → scroll de rueda en esa posición.
//
// Hover: solo se apagó el SINTÉTICO (el que el emisor inyectaba en cada paso de
// flecha, que resaltaba la capa de atrás al desplazarse). El hover del mouse
// REAL / air mouse se deja intacto a propósito: lo manda el sistema, sigue al
// puntero físico y es la única señal que trae el movimiento sin botones (de la
// que depende el seguimiento del cursor). Neutralizarlo no se puede sin romper
// el air mouse, y este widget también se monta en Android ancho (esSmartTV por
// ancho), donde el hover es legítimo. Ver puntero_tv_estado.dart.
//
// Doble cursor: con un mouse/air mouse REAL la tele dibuja su propio cursor del
// sistema, así que acá el aro propio se esconde (opacidad 0) y queda visible
// SOLO mientras se navega con el D-pad, que es cuando no hay ningún cursor
// nativo que muestre dónde se está parado. Ojo: esconderlo es visual — el aro
// sigue el puntero real por debajo (ver `adoptarPunteroReal`), que es lo que
// hace que el clic del control caiga donde el usuario lo ve.
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
      initPuntero();
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
        // El contenido escucha los eventos de puntero SOLO para seguir al
        // mouse real (air mouse / control con giroscopio): así el cursor
        // dibujado y el del control son el mismo y el clic cae donde se ve.
        // `translucent` deja pasar los eventos al árbol de gestos de siempre.
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: adoptarPunteroReal,
          onPointerMove: adoptarPunteroReal,
          onPointerDown: adoptarPunteroReal,
          child: widget.child,
        ),
        Positioned(
          left: posCursor.dx - PunteroTv.radio,
          top: posCursor.dy - PunteroTv.radio,
          child: IgnorePointer(
            // Con mouse/air mouse real el aro se apaga (la tele ya muestra su
            // cursor: dos flechas a la vez se ve mal) y vuelve apenas se usa el
            // D-pad. Se apaga con opacidad y NO se desmonta, así el clic sigue
            // cayendo exactamente donde está el cursor.
            child: AnimatedOpacity(
              opacity: usandoMouseReal ? 0 : 1,
              duration: const Duration(milliseconds: 120),
              child: CursorTv(
                key: PunteroTv.claveCursor,
                presionando: presionandoCursor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
