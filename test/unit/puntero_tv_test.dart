// puntero_tv_test.dart — Verifica el puntero virtual de TV y el lienzo de
// diseño fijo, que son los dos bugs reportados en televisores:
//
//   1. "Hago clic en el minijugador y presiona una card": el clic sintético
//      caía en otro sitio (y era un toque, sin hover, así que el resaltado se
//      quedaba en el último foco). Ahora es un MOUSE y el clic tiene que caer
//      exactamente donde se dibuja el cursor.
//   2. "Hay mucho scroll y el diseño no se ajusta a la pantalla sin importar
//      el DPI": el layout recibía el ancho que reportara cada televisor. Ahora
//      recibe siempre el mismo ancho lógico y se escala para llenar.
//
// Se conecta con: shared/widgets/tv/puntero_tv.dart y
// shared/utilidades/plataforma/vista_tv.dart.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/shared/utilidades/plataforma/vista_tv.dart';
import 'package:bitly/shared/widgets/tv/puntero_tv.dart';

/// App mínima de prueba: un área que ocupa todo y reporta cada clic (con su
/// posición global) y el tipo de dispositivo del puntero que lo produjo.
Widget _appDePrueba({
  required List<Offset> clics,
  required List<PointerDeviceKind> dispositivos,
}) {
  return MaterialApp(
    home: PunteroTv(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (evento) => dispositivos.add(evento.kind),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (detalle) => clics.add(detalle.globalPosition),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

/// Sonda que imprime el tamaño lógico que recibe del lienzo.
class _SondaTv extends StatelessWidget {
  const _SondaTv();

  @override
  Widget build(BuildContext context) {
    final tam = MediaQuery.sizeOf(context);
    return Text(
      'ancho:${tam.width.toStringAsFixed(1)} alto:${tam.height.toStringAsFixed(1)}',
    );
  }
}

void main() {
  group('puntero de TV', () {
    testWidgets('las flechas mueven el cursor', (tester) async {
      final clics = <Offset>[];
      final dispositivos = <PointerDeviceKind>[];
      await tester.pumpWidget(
        _appDePrueba(clics: clics, dispositivos: dispositivos),
      );

      // Arranca centrado (800x600 de superficie de prueba).
      final inicio = tester.getCenter(find.byKey(PunteroTv.claveCursor));
      expect(inicio, const Offset(400, 300));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      final movido = tester.getCenter(find.byKey(PunteroTv.claveCursor));
      expect(movido, const Offset(424, 300),
          reason: 'la flecha debe mover el cursor 24px a la derecha');
    });

    testWidgets('OK hace clic de mouse donde está el cursor', (tester) async {
      final clics = <Offset>[];
      final dispositivos = <PointerDeviceKind>[];
      await tester.pumpWidget(
        _appDePrueba(clics: clics, dispositivos: dispositivos),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 120));

      expect(clics, hasLength(1));
      expect(dispositivos, [PointerDeviceKind.mouse],
          reason: 'el clic debe ser de mouse, no un toque sintético');
      expect(
        clics.single,
        tester.getCenter(find.byKey(PunteroTv.claveCursor)),
        reason: 'el clic tiene que caer donde se dibuja el cursor, '
            'que era exactamente el bug de "presiona otra card"',
      );
    });

    testWidgets('la rueda (canal +) hace scroll sin mover el cursor',
        (tester) async {
      final clics = <Offset>[];
      final dispositivos = <PointerDeviceKind>[];
      await tester.pumpWidget(
        _appDePrueba(clics: clics, dispositivos: dispositivos),
      );

      final antes = tester.getCenter(find.byKey(PunteroTv.claveCursor));
      await tester.sendKeyEvent(LogicalKeyboardKey.channelDown);
      await tester.pump();

      expect(tester.getCenter(find.byKey(PunteroTv.claveCursor)), antes);
      expect(clics, isEmpty);
    });

    testWidgets('con un campo de texto enfocado el puntero sigue mandando',
        (tester) async {
      // En TV el cursor es la única forma de moverse: el foco de un campo de
      // texto no puede dejarlo "apagado" (era la causa del desfase).
      final clics = <Offset>[];
      final dispositivos = <PointerDeviceKind>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PunteroTv(
            child: Scaffold(
              body: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (evento) => dispositivos.add(evento.kind),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (detalle) => clics.add(detalle.globalPosition),
                  child: const SizedBox.expand(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: TextField(autofocus: true),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final antes = tester.getCenter(find.byKey(PunteroTv.claveCursor));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        tester.getCenter(find.byKey(PunteroTv.claveCursor)).dy,
        greaterThan(antes.dy),
        reason: 'las flechas son del puntero aunque haya un campo enfocado',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 120));
      expect(clics, hasLength(1));
    });
  });

  group('lienzo de diseño de TV', () {
    testWidgets('siempre entrega el mismo ancho lógico, sin importar el DPI',
        (tester) async {
      Future<void> probar(Size fisico) async {
        tester.view.physicalSize = fisico;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) =>
                  vistaDisenoTv(context: context, child: const _SondaTv()),
            ),
          ),
        );
      }

      // Misma TV, tres densidades distintas → tres anchos lógicos distintos.
      for (final fisico in const [
        Size(1920, 1080),
        Size(1280, 720),
        Size(960, 540),
      ]) {
        await probar(fisico);
        expect(find.text('ancho:1280.0 alto:720.0'), findsOneWidget,
            reason: 'el layout no debe depender del DPI del televisor');
      }

      tester.view.reset();
    });

    testWidgets('fuera de TV no toca nada', (tester) async {
      // Un celular: ancho chico, plataforma Android pero por debajo del umbral
      // de TV, así que el lienzo no debe activarse.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) =>
                vistaDisenoTv(context: context, child: const _SondaTv()),
          ),
        ),
      );

      expect(find.text('ancho:400.0 alto:800.0'), findsOneWidget);
    });
  });
}
