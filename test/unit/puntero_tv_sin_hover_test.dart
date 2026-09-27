// puntero_tv_sin_hover_test.dart — El puntero de TV SOLO manda la pulsación real.
//
// El bug reportado: "al mover el puntero, la capa de atrás igual interactúa con
// el movimiento". Con las flechas del control, cada paso movía el cursor y, de
// paso, inyectaba un `PointerHoverEvent` en la posición nueva: eso resaltaba
// (InkWell/MouseRegion) la card o el botón que quedaban debajo, así que parecía
// que "saltaba" de una tarjeta a otra y, cuando la lista se terminaba, a un
// ícono. Ese es el "clic falso" que saltaba entre canciones/vistas o resaltaba
// un dropdown.
//
// La regla que fija este test: MOVER no manda nada al árbol, y el CLIC manda
// solo `down` + `up` (nunca un hover aparte). El resaltado aparece en la
// pulsación porque el propio `PointerDown` actualiza el hover del framework —
// el `PointerHoverEvent` que se mandaba antes era redundante.
//
// Usa el árbol REAL de la app (lienzo de diseño + protección de layout +
// puntero encima), como puntero_tv_padding_test.dart.
//
// Se conecta con: lib/shared/widgets/tv/puntero_tv_estado.dart (el `_mover` que
// dejó de mandar hover) + puntero_tv_eventos.dart (`clicar` sin hover).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/shared/utilidades/plataforma/pantalla/escala_texto.dart';
import 'package:bitly/shared/utilidades/plataforma/tv/vista_tv.dart';
import 'package:bitly/shared/widgets/tv/puntero_tv.dart';

/// Blanco que avisa cuándo el hover entra y cuándo lo tocan.
class _Blanco extends StatelessWidget {
  const _Blanco({
    required this.etiqueta,
    required this.entraHover,
    required this.taps,
  });

  final String etiqueta;
  final List<String> entraHover;
  final List<String> taps;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => entraHover.add(etiqueta),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => taps.add(etiqueta),
        child: Container(
          alignment: Alignment.center,
          color: Colors.blueGrey,
          child: Text(etiqueta),
        ),
      ),
    );
  }
}

/// Registra el TIPO de cada evento de puntero que llega a la capa de atrás.
class _SondaEventos extends StatelessWidget {
  const _SondaEventos({required this.eventos, required this.child});

  final List<String> eventos;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (_) => eventos.add('hover'),
      onPointerDown: (_) => eventos.add('down'),
      onPointerUp: (_) => eventos.add('up'),
      onPointerSignal: (_) => eventos.add('scroll'),
      child: child,
    );
  }
}

/// Reproduce el montaje de app.dart para TV: lienzo de diseño + protección de
/// layout + puntero POR ENCIMA (píxeles reales de pantalla).
Widget _appTvReal({
  required List<String> entraHover,
  required List<String> taps,
  required Widget cuadricula,
}) {
  return MaterialApp(
    builder: (context, hijo) {
      Widget contenido = hijo ?? const SizedBox.shrink();
      contenido = vistaDisenoTv(context: context, child: contenido);
      contenido = protegerLayout(context: context, child: contenido);
      return PunteroTv(child: contenido);
    },
    home: cuadricula,
  );
}

/// Dos blancos lado a lado (mitad izquierda / mitad derecha).
Widget _dosBlancos({
  required List<String> entraHover,
  required List<String> taps,
}) {
  return Row(
    children: [
      Expanded(
        child: _Blanco(
          etiqueta: 'IZQUIERDA',
          entraHover: entraHover,
          taps: taps,
        ),
      ),
      Expanded(
        child: _Blanco(
          etiqueta: 'DERECHA',
          entraHover: entraHover,
          taps: taps,
        ),
      ),
    ],
  );
}

void main() {
  group('puntero de TV: mover no toca la capa de atrás', () {
    testWidgets('las flechas no disparan hover en lo que hay debajo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final entra = <String>[];
      final taps = <String>[];
      await tester.pumpWidget(
        _appTvReal(
          entraHover: entra,
          taps: taps,
          cuadricula: _dosBlancos(entraHover: entra, taps: taps),
        ),
      );

      // Recorre el cursor por encima de los dos bloques (y de borde a borde).
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
      }
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }

      expect(
        entra,
        isEmpty,
        reason:
            'mover es solo visual: la capa de atrás no debe reaccionar al '
            'desplazamiento (era el "clic falso" que saltaba de una card a '
            'otra y, al acabarse, a un ícono/ícono de un dropdown)',
      );
      expect(taps, isEmpty, reason: 'mover tampoco activa nada');
    });

    testWidgets('el clic manda SOLO down+up, nunca un hover aparte', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final eventos = <String>[];
      final entra = <String>[];
      final taps = <String>[];
      await tester.pumpWidget(
        _appTvReal(
          entraHover: entra,
          taps: taps,
          cuadricula: _SondaEventos(
            eventos: eventos,
            child: _dosBlancos(entraHover: entra, taps: taps),
          ),
        ),
      );

      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
      }
      expect(eventos, isEmpty, reason: 'mover no manda ningún evento');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        eventos,
        ['down', 'up'],
        reason:
            'el clic solo inyecta la pulsación: el hover ya es redundante '
            'porque el propio down actualiza el resaltado del framework',
      );
    });

    testWidgets('el scroll (canal +) llega sin mandar hover', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final eventos = <String>[];
      final entra = <String>[];
      final taps = <String>[];
      await tester.pumpWidget(
        _appTvReal(
          entraHover: entra,
          taps: taps,
          cuadricula: _SondaEventos(
            eventos: eventos,
            child: _dosBlancos(entraHover: entra, taps: taps),
          ),
        ),
      );

      final antes = tester.getCenter(find.byKey(PunteroTv.claveCursor));
      await tester.sendKeyEvent(LogicalKeyboardKey.channelDown);
      await tester.pump();

      expect(eventos, ['scroll'], reason: 'la rueda llega, y sin hover');
      expect(
        tester.getCenter(find.byKey(PunteroTv.claveCursor)),
        antes,
        reason: 'scrollear no mueve el cursor',
      );
      expect(entra, isEmpty, reason: 'scrollear tampoco debe resaltar el fondo');
    });

    testWidgets('después de mover, el clic cae bajo el cursor y resalta ahí', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final entra = <String>[];
      final taps = <String>[];
      await tester.pumpWidget(
        _appTvReal(
          entraHover: entra,
          taps: taps,
          cuadricula: _dosBlancos(entraHover: entra, taps: taps),
        ),
      );

      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
      }
      final cursor = tester.getCenter(find.byKey(PunteroTv.claveCursor));
      expect(cursor.dx, lessThan(960.0));
      expect(entra, isEmpty, reason: 'todavía no se pulsó nada');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        taps,
        ['IZQUIERDA'],
        reason: 'dejar de mandar hover no puede romper el clic',
      );
      expect(
        entra,
        ['IZQUIERDA'],
        reason:
            'el resaltado de la capa de atrás aparece SOLO con la pulsación, y '
            'solo en el widget que el cursor tiene debajo',
      );

      // Segunda pulsación en otro sitio: el resaltado debe SEGUIR a la
      // pulsación (no quedarse pegado en la primera).
      for (var i = 0; i < 24; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        entra,
        contains('DERECHA'),
        reason: 'el resaltado acompaña a cada pulsación, no se queda en la vieja',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Mouse REAL / air mouse: acá NO se neutraliza el hover, a propósito.
  //
  // Con las flechas el hover era SINTÉTICO (lo inyectaba el emisor en cada
  // paso) y por eso se apagó. Con un mouse/air mouse el puntero existe de
  // verdad: el hover lo manda el sistema, sigue al puntero físico y su único
  // efecto es marcar lo que está debajo. Neutralizarlo no se puede hacer sin
  // romper el seguimiento del cursor (el movimiento sin botones llega SOLO
  // como `PointerHoverEvent`) y `PunteroTv` también se monta en Android ancho,
  // donde el hover es legítimo. Lo que estos tests fijan es que el hover real
  // marca pero NUNCA activa, y que el clic cae donde está el puntero.
  // ─────────────────────────────────────────────────────────────
  group('mouse real / air mouse: hover marcador, nunca activador', () {
    testWidgets('el hover real sigue al puntero y no activa nada', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final entra = <String>[];
      final taps = <String>[];
      await tester.pumpWidget(
        _appTvReal(
          entraHover: entra,
          taps: taps,
          cuadricula: _dosBlancos(entraHover: entra, taps: taps),
        ),
      );

      final gesto = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesto.addPointer(location: const Offset(1400, 540));
      await gesto.moveTo(const Offset(400, 540));
      await tester.pump();

      // El cursor DIBUJADO sigue al puntero real (soporte de air mouse): si no,
      // el clic del control caería sobre otra tarjeta.
      expect(
        tester.getCenter(find.byKey(PunteroTv.claveCursor)),
        const Offset(400, 540),
        reason: 'el cursor dibujado debe ir donde tiene el puntero el control',
      );
      // El hover real SÍ marca la capa de atrás: es intencional (el puntero
      // físico está encima). No es el bug: el bug era mover con las flechas.
      expect(
        entra,
        contains('IZQUIERDA'),
        reason: 'el hover real marca lo que el puntero tiene debajo',
      );
      // Y lo que jamás debe pasar: que pasar el mouse por encima active algo.
      expect(
        taps,
        isEmpty,
        reason: 'el hover no activa: solo la pulsación activa',
      );

      await gesto.removePointer();
    });

    testWidgets('el clic del mouse real cae donde está el puntero', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final entra = <String>[];
      final taps = <String>[];
      await tester.pumpWidget(
        _appTvReal(
          entraHover: entra,
          taps: taps,
          cuadricula: _dosBlancos(entraHover: entra, taps: taps),
        ),
      );

      final gesto = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesto.addPointer(location: const Offset(1400, 540));
      await tester.pump();
      await gesto.down(const Offset(1400, 540));
      await gesto.up();
      await tester.pump();

      expect(
        taps,
        ['DERECHA'],
        reason: 'el clic del mouse real tiene que caer bajo el puntero',
      );

      await gesto.removePointer();
    });
  });
}
