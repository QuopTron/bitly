// ─────────────────────────────────────────────────────────────
// puntero_tv.dart — Puntero virtual para TV (Android TV / Google TV / Fire TV).
//
// Por qué existe: la app está diseñada para el dedo, y en TV el control remoto
// solo manda flechas. Sin puntero, el usuario queda encerrado: no hay dónde
// "hacer foco" ni forma de tocar un botón que está a mitad de pantalla.
//
// Qué hace: dibuja un cursor sobre la app y lo maneja con el control remoto.
//   - Flechas del D-pad  → mueven el cursor (con aceleración al mantener).
//   - OK / Enter / Space → clic EN LA POSICIÓN del cursor: se sintetizan los
//                          eventos de un toque real, así funciona cualquier
//                          widget táctil de la app sin tocar sus pantallas.
//   - Canal +/- / PageUp/Down → envía un scroll de rueda en esa posición, para
//                          recorrer listas y grillas sin arrastrar.
//
// Detalle importante: mientras un campo de texto tiene el foco (buscador,
// ajustes) el puntero se aparta y devuelve las flechas al campo, para que
// escribir en TV siga funcionando como siempre.
//
// Se conecta con: app.dart (lo monta solo cuando esSmartTV) y flutter/gestures
// (handlePointerEvent).
// Parte del flujo: entrada de usuario en TV.
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Envuelve [child] con un puntero manejable por control remoto.
class PunteroTv extends StatefulWidget {
  final Widget child;

  /// Radio visual del cursor.
  static const double radio = 13;

  const PunteroTv({super.key, required this.child});

  @override
  State<PunteroTv> createState() => _PunteroTvState();
}

class _PunteroTvState extends State<PunteroTv> {
  /// Cuánto se mueve el cursor por pulsación (se multiplica al mantener).
  static const double _paso = 24;

  /// Velocidad del scroll de rueda por pulsación (px lógicos).
  static const double _pasoScroll = 120;

  /// Id propio del puntero sintético: reusar el mismo evita que el framework
  /// crea que son dispositivos distintos.
  static const int _idPuntero = 777;

  Offset _pos = Offset.zero;
  bool _posicionado = false;
  bool _presionando = false;

  DateTime? _ultimaTecla;
  int _repeticion = 0;

  @override
  void initState() {
    super.initState();
    // Handler GLOBAL (no depende del foco): el puntero tiene que responder
    // aunque no haya ningún widget enfocado, que es el caso normal en TV.
    HardwareKeyboard.instance.addHandler(_alTeclado);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_posicionado) {
      final tam = MediaQuery.sizeOf(context);
      _pos = Offset(tam.width / 2, tam.height / 2);
      _posicionado = true;
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_alTeclado);
    super.dispose();
  }

  /// True si el usuario está escribiendo: ahí las flechas son del campo de
  /// texto (mover el caret), no del puntero.
  bool _escribiendo() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  /// Delta de movimiento (o null) para una tecla del D-pad.
  Offset? _deltaDe(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return const Offset(0, -_paso);
    if (key == LogicalKeyboardKey.arrowDown) return const Offset(0, _paso);
    if (key == LogicalKeyboardKey.arrowLeft) return const Offset(-_paso, 0);
    if (key == LogicalKeyboardKey.arrowRight) return const Offset(_paso, 0);
    return null;
  }

  /// Delta de scroll para las teclas de canal / página.
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

  /// False para devolverle las flechas al campo de texto o a un combo.
  bool _debeIgnorar() {
    if (!mounted) return true;
    return _escribiendo();
  }

  bool _alTeclado(KeyEvent evento) {
    if (_debeIgnorar()) return false;

    final key = evento.logicalKey;
    final esRepeticion = evento is KeyRepeatEvent;
    final esBaja = evento is KeyDownEvent;
    final esAlza = evento is KeyUpEvent;

    final delta = _deltaDe(key);
    if (delta != null) {
      if (esAlza) {
        _repeticion = 0;
        _ultimaTecla = null;
        return true;
      }
      if (esBaja || esRepeticion) {
        _mover(delta);
        return true;
      }
    }

    if (_esClic(key)) {
      // Solo en la bajada inicial: una repetición no debe disparar otro clic.
      if (esBaja) _clicar();
      return true;
    }

    final scroll = _scrollDe(key);
    if (scroll != null) {
      if (esBaja || esRepeticion) _desplazar(scroll);
      return true;
    }

    return false;
  }

  /// Mueve el cursor, acelerando si el usuario mantiene la flecha apretada:
  /// cruzar la pantalla pulsa a pulsa sería eterno.
  void _mover(Offset delta) {
    final ahora = DateTime.now();
    final seguido =
        _ultimaTecla != null &&
        ahora.difference(_ultimaTecla!).inMilliseconds < 600;
    _repeticion = seguido ? (_repeticion + 1).clamp(0, 20) : 0;
    _ultimaTecla = ahora;

    final factor = 1 + _repeticion * 0.16;
    final tam = MediaQuery.sizeOf(context);
    final nueva = Offset(
      (_pos.dx + delta.dx * factor).clamp(0.0, tam.width),
      (_pos.dy + delta.dy * factor).clamp(0.0, tam.height),
    );
    setState(() => _pos = nueva);
  }

  /// Simula un toque en la posición del cursor. Se manda un PointerDown y,
  /// poco después, un PointerUp: es exactamente la secuencia que produce el
  /// dedo, así que los botones, listas y tarjetas de la app responden sin que
  /// ninguna pantalla tenga que saber que existe un control remoto.
  void _clicar() {
    if (_presionando) return;
    _presionando = true;
    setState(() {});

    final pos = _pos;
    WidgetsBinding.instance.handlePointerEvent(
      PointerDownEvent(
        position: pos,
        pointer: _idPuntero,
        device: 1,
        kind: PointerDeviceKind.touch,
      ),
    );
    Timer(const Duration(milliseconds: 70), () {
      WidgetsBinding.instance.handlePointerEvent(
        PointerUpEvent(
          position: pos,
          pointer: _idPuntero,
          device: 1,
          kind: PointerDeviceKind.touch,
        ),
      );
      if (mounted) setState(() => _presionando = false);
    });
  }

  /// Manda un scroll de rueda en la posición del cursor para recorrer listas.
  void _desplazar(double dy) {
    WidgetsBinding.instance.handlePointerEvent(
      PointerScrollEvent(
        position: _pos,
        scrollDelta: Offset(0, dy),
        kind: PointerDeviceKind.mouse,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // El cursor nunca intercepta toques ni taps sintéticos: solo se dibuja.
        Positioned(
          left: _pos.dx - PunteroTv.radio,
          top: _pos.dy - PunteroTv.radio,
          child: IgnorePointer(
            child: _CursorTv(presionando: _presionando),
          ),
        ),
      ],
    );
  }
}

/// El cursor: aro blanco con borde oscuro (para que se vea sobre cualquier
/// fondo) y punto verde que se contrae al hacer clic, como feedback.
class _CursorTv extends StatelessWidget {
  final bool presionando;

  const _CursorTv({required this.presionando});

  static const Color _verde = Color(0xFF1DB954);

  @override
  Widget build(BuildContext context) {
    final lado = PunteroTv.radio * 2;
    return AnimatedScale(
      scale: presionando ? 0.82 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: presionando ? 0.9 : 0.72),
          border: Border.all(color: Colors.black.withValues(alpha: 0.55), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _verde,
            ),
          ),
        ),
      ),
    );
  }
}
