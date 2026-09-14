// ─────────────────────────────────────────────────────────────
// puntero_tv.dart — Puntero virtual para TV (Android TV / Google TV / Fire TV).
//
// Por qué existe: la app está diseñada para el dedo, y en TV el control remoto
// solo manda flechas. Sin puntero, el usuario queda encerrado: no hay dónde
// "hacer foco" ni forma de tocar un botón que está a mitad de pantalla.
//
// Qué hace: dibuja un cursor y lo maneja con el control remoto.
//   - Flechas del D-pad  → mueven el cursor (con aceleración al mantener).
//   - OK / Enter / Space → clic EN LA POSICIÓN del cursor.
//   - Canal +/- / PageUp/Down → scroll de rueda en esa posición, para recorrer
//                          listas y grillas sin arrastrar.
//
// Cómo hace el clic (esto es lo que estaba mal antes): emula un MOUSE, no un
// dedo.
//   * Al moverse manda un PointerHoverEvent: el resaltado sigue al cursor, así
//     el usuario ve exactamente qué va a activar. Con un toque sintético no hay
//     hover, el resaltado se queda en el último widget con foco y por eso
//     parecía que "el puntero y la selección estaban desfasados".
//   * Al hacer clic manda PointerDown/Up con kind: mouse: activa el widget que
//     está DEBAJO del cursor, y no el que quedó con foco (que era la causa de
//     "hago clic en el miniplayer y presiona una card").
//
// Coordenadas: el cursor se dibuja en el espacio LOCAL del Stack, pero los
// eventos van en coordenadas GLOBALES (las que espera handlePointerEvent). La
// conversión se hace con el RenderBox, así el clic cae exactamente donde se ve
// el cursor aunque la app esté dentro de un FittedBox (viewport de TV o
// protección por densidad).
//
// Las flechas SIEMPRE son del puntero, incluso con un campo de texto enfocado:
// en TV el cursor es la única forma de moverse por la app. Para escribir, el
// usuario hace clic en el campo (el clic de mouse coloca el caret) y teclea;
// las letras y los números no se interceptan.
//
// Se conecta con: app.dart (lo monta solo cuando esSmartTV, por ENCIMA del
// viewport de diseño) y flutter/gestures (handlePointerEvent).
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

  /// Clave del cursor: permite ubicarlo (y probar que el clic cae justo ahí).
  static const Key claveCursor = Key('bitly-puntero-tv-cursor');

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
  /// crea que son dispositivos distintos (y que el hover se pierda).
  static const int _idPuntero = 777;

  /// Cuánto se separa el cursor del borde físico. En 0 el cursor puede quedar
  /// justo en x=ancho (o y=alto), que ya está FUERA del área de hit testing.
  static const double _margenBorde = 0.5;

  Offset _pos = Offset.zero;
  bool _posicionado = false;
  bool _presionando = false;

  /// El dispositivo de mouse tiene que estar "agregado" antes de cualquier
  /// hover; si no, MouseTracker descarta el evento y no hay resaltado.
  bool _mouseAgregado = false;

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
    if (_posicionado) return;
    _pos = _centro();
    _posicionado = true;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_alTeclado);
    if (_mouseAgregado) {
      _enviar(
        PointerRemovedEvent(
          device: _idPuntero,
          kind: PointerDeviceKind.mouse,
        ),
      );
    }
    super.dispose();
  }

  /// Caja del widget: da el tamaño real y la conversión local → global.
  RenderBox? get _caja {
    final ro = context.findRenderObject();
    return ro is RenderBox && ro.hasSize ? ro : null;
  }

  Size get _tamano => _caja?.size ?? MediaQuery.sizeOf(context);

  Offset _centro() {
    final t = _tamano;
    return Offset(t.width / 2, t.height / 2);
  }

  /// Pasa una posición en el espacio del cursor al espacio de la PANTALLA
  /// (el que usa handlePointerEvent). Tiene en cuenta cualquier transformación
  /// de los ancestros (FittedBox del viewport de TV, protección por densidad).
  Offset _global(Offset local) {
    final caja = _caja;
    if (caja == null) return local;
    return caja.localToGlobal(local);
  }

  void _enviar(PointerEvent evento) {
    try {
      WidgetsBinding.instance.handlePointerEvent(evento);
    } catch (_) {
      // El árbol puede estar desmontándose (salida de la app): nunca tirar.
    }
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

  bool _alTeclado(KeyEvent evento) {
    if (!mounted) return false;

    final key = evento.logicalKey;

    // 1) Flechas: mueven el cursor. Siempre, aunque haya un campo enfocado.
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

    // 2) OK / Enter: clic en la posición del cursor (solo en la bajada).
    if (_esClic(key)) {
      if (evento is KeyDownEvent) _clicar();
      return true;
    }

    // 3) Canal / página: scroll en la posición del cursor.
    final scroll = _scrollDe(key);
    if (scroll != null) {
      if (evento is! KeyUpEvent) _desplazar(scroll);
      return true;
    }

    return false;
  }

  /// Mueve el cursor, acelerando si el usuario mantiene la flecha apretada:
  /// cruzar la pantalla pulsada a pulsada sería eterno.
  void _mover(Offset delta) {
    final ahora = DateTime.now();
    final seguido =
        _ultimaTecla != null &&
        ahora.difference(_ultimaTecla!).inMilliseconds < 600;
    _repeticion = seguido ? (_repeticion + 1).clamp(0, 20) : 0;
    _ultimaTecla = ahora;

    final factor = 1 + _repeticion * 0.16;
    final t = _tamano;
    // El tope es [size - _margenBorde] y no [size]: un clic en la coordenada
    // EXACTA del ancho/alto cae fuera de la pantalla (hit testing usa rangos
    // semiabiertos), así que el cursor podía quedar pegado a la esquina y el
    // clic no activaba nada — el botón de la esquina del miniplayer era
    // imposible de tocar.
    final nueva = Offset(
      (_pos.dx + delta.dx * factor).clamp(
        _margenBorde,
        t.width - _margenBorde,
      ),
      (_pos.dy + delta.dy * factor).clamp(
        _margenBorde,
        t.height - _margenBorde,
      ),
    );
    setState(() => _pos = nueva);
    _enviarHover();
  }

  /// Manda el hover del mouse para que el resaltado siga al cursor. El primer
  /// evento es un PointerAddedEvent: sin él, MouseTracker ignora el hover.
  void _enviarHover() {
    final g = _global(_pos);
    if (!_mouseAgregado) {
      _mouseAgregado = true;
      _enviar(
        PointerAddedEvent(
          device: _idPuntero,
          kind: PointerDeviceKind.mouse,
          position: g,
        ),
      );
    }
    _enviar(
      PointerHoverEvent(
        device: _idPuntero,
        kind: PointerDeviceKind.mouse,
        position: g,
        buttons: 0,
      ),
    );
  }

  /// Clic de mouse en la posición del cursor: PointerDown y, poco después,
  /// PointerUp. Es la misma secuencia que manda un mouse real, así que los
  /// botones, listas y tarjetas responden sin que ninguna pantalla sepa que
  /// existe un control remoto.
  void _clicar() {
    if (_presionando) return;
    _presionando = true;
    setState(() {});

    // El dispositivo tiene que estar agregado (hover) antes del clic.
    _enviarHover();
    final g = _global(_pos);

    _enviar(
      PointerDownEvent(
        device: _idPuntero,
        kind: PointerDeviceKind.mouse,
        position: g,
        buttons: kPrimaryButton,
      ),
    );
    Timer(const Duration(milliseconds: 70), () {
      _enviar(
        PointerUpEvent(
          device: _idPuntero,
          kind: PointerDeviceKind.mouse,
          position: g,
          buttons: 0,
        ),
      );
      if (mounted) setState(() => _presionando = false);
    });
  }

  /// Manda un scroll de rueda en la posición del cursor para recorrer listas.
  void _desplazar(double dy) {
    _enviarHover();
    _enviar(
      PointerScrollEvent(
        device: _idPuntero,
        kind: PointerDeviceKind.mouse,
        position: _global(_pos),
        scrollDelta: Offset(0, dy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      // StackFit.expand NO es un detalle de estilo: con el `loose` por defecto
      // (el de antes) el hijo recibía restricciones FLOJAS, así que el
      // `FittedBox` del lienzo de TV (`vistaDisenoTv`) se dimensionaba a su
      // HIJO (1280x720) en vez de a la pantalla — y como FittedBox solo escala
      // cuando lo que manda es la caja del padre, NO escalaba nada.
      //
      // Consecuencia medida (test/unit/puntero_tv_padding_test.dart): en una TV
      // de 1920x1080 la app se dibujaba a 1280x720 pegada a la esquina, mientras
      // el puntero recorría los 1920x1080 reales. El cursor pasaba de largo del
      // contenido (mitad de pantalla muerta) y, dentro del contenido, el clic
      // caía 1,5 veces más a la derecha de donde se veía el cursor — el "hago
      // clic acá y presiona allá" de la TV.
      //
      // Con expand, el hijo recibe restricciones EXACTAS (el tamaño real de la
      // pantalla), el FittedBox escala el lienzo para llenar y el hit testing
      // invierte esa misma transformación: el clic cae donde está el cursor.
      fit: StackFit.expand,
      children: [
        widget.child,
        // El cursor nunca intercepta eventos: solo se dibuja.
        Positioned(
          left: _pos.dx - PunteroTv.radio,
          top: _pos.dy - PunteroTv.radio,
          child: IgnorePointer(
            child: _CursorTv(
              key: PunteroTv.claveCursor,
              presionando: _presionando,
            ),
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

  const _CursorTv({super.key, required this.presionando});

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
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.55),
            width: 2,
          ),
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
