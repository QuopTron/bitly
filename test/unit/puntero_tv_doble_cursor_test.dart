// puntero_tv_doble_cursor_test.dart — El aro dibujado no se pisa con el cursor
// del sistema (doble cursor en TV).
//
// El bug reportado: en la tele, al mover el air mouse, se veían DOS cursores —
// el del sistema (que dibuja la propia TV) y el aro que dibuja la app. El aro
// hace falta para el D-pad (con el control remoto no hay ningún cursor nativo
// que indique dónde se está parado), pero sobra cuando el puntero ya existe de
// verdad.
//
// La regla que fija este test:
//   - con el D-pad (flechas / OK / canal) el aro se ve;
//   - con un mouse/air mouse REAL el aro se esconde;
//   - esconderlo es solo visual: el aro sigue al puntero real por debajo, así
//     que el clic del control sigue cayendo donde el usuario lo ve;
//   - en cuanto se vuelve al D-pad el aro reaparece.
//
// Usa el árbol REAL de la app (lienzo de diseño + protección de layout +
// puntero encima), como puntero_tv_padding_test.dart.
//
// Se conecta con: lib/shared/widgets/tv/puntero_tv_estado.dart (la marca
// `usandoMouseReal`) + puntero_tv.dart (la capa visual que la lee).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/shared/utilidades/plataforma/pantalla/escala_texto.dart';
import 'package:bitly/shared/utilidades/plataforma/tv/vista_tv.dart';
import 'package:bitly/shared/widgets/tv/puntero_tv.dart';

/// Blanco que registra los taps: sirve para comprobar que esconder el aro no
/// rompe el clic del air mouse.
class _Blanco extends StatelessWidget {
  const _Blanco({required this.etiqueta, required this.taps});

  final String etiqueta;
  final List<String> taps;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => taps.add(etiqueta),
      child: Container(
        alignment: Alignment.center,
        color: Colors.blueGrey,
        child: Text(etiqueta),
      ),
    );
  }
}

/// Reproduce el montaje de app.dart para TV: lienzo de diseño + protección de
/// layout + puntero POR ENCIMA (píxeles reales de pantalla).
Widget _appTvReal({required List<String> taps}) {
  return MaterialApp(
    builder: (context, hijo) {
      Widget contenido = hijo ?? const SizedBox.shrink();
      contenido = vistaDisenoTv(context: context, child: contenido);
      contenido = protegerLayout(context: context, child: contenido);
      return PunteroTv(child: contenido);
    },
    home: Row(
      children: [
        Expanded(child: _Blanco(etiqueta: 'IZQUIERDA', taps: taps)),
        Expanded(child: _Blanco(etiqueta: 'DERECHA', taps: taps)),
      ],
    ),
  );
}

/// Opacidad objetivo del aro dibujado (1 = visible, 0 = escondido).
double _opacidadDelAro(WidgetTester tester) {
  final animado = tester.widget<AnimatedOpacity>(
    find.ancestor(
      of: find.byKey(PunteroTv.claveCursor),
      matching: find.byType(AnimatedOpacity),
    ),
  );
  return animado.opacity;
}

void main() {
  group('puntero de TV: un solo cursor', () {
    testWidgets('con el D-pad el aro dibujado se ve', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final taps = <String>[];
      await tester.pumpWidget(_appTvReal(taps: taps));

      expect(_opacidadDelAro(tester), 1, reason: 'arranca con el aro visible');

      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
      }
      expect(_opacidadDelAro(tester), 1, reason: 'las flechas no lo esconden');

      // El OK del control emula un puntero, pero es NUESTRO puntero (device
      // 777), no un mouse de verdad: tiene que seguir viéndose el aro.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        _opacidadDelAro(tester),
        1,
        reason: 'el clic del control remoto no es un mouse real',
      );
      expect(taps, ['IZQUIERDA']);
    });

    testWidgets('con el mouse real el aro se esconde, pero sigue apuntando', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final taps = <String>[];
      await tester.pumpWidget(_appTvReal(taps: taps));

      final gesto = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesto.addPointer(location: const Offset(1400, 540));
      await gesto.moveTo(const Offset(400, 540));
      await tester.pump();

      expect(
        _opacidadDelAro(tester),
        0,
        reason:
            'la tele ya dibuja su cursor: el aro propio tiene que apagarse '
            '(era el doble cursor reportado)',
      );
      // Esconderlo es visual: por debajo sigue al puntero real, y por eso el
      // clic del control sigue cayendo donde se ve.
      expect(
        tester.getCenter(find.byKey(PunteroTv.claveCursor)),
        const Offset(400, 540),
        reason: 'el aro escondido tiene que seguir al puntero real',
      );

      await gesto.down(const Offset(400, 540));
      await gesto.up();
      await tester.pump();

      expect(
        taps,
        ['IZQUIERDA'],
        reason: 'esconder el aro no puede romper el clic del air mouse',
      );
      expect(
        _opacidadDelAro(tester),
        0,
        reason: 'el clic del mouse real no vuelve a mostrar el aro',
      );

      await gesto.removePointer();
    });

    testWidgets('al volver al D-pad el aro reaparece', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final taps = <String>[];
      await tester.pumpWidget(_appTvReal(taps: taps));

      final gesto = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesto.addPointer(location: const Offset(1400, 540));
      await gesto.moveTo(const Offset(1400, 540));
      await tester.pump();
      expect(_opacidadDelAro(tester), 0, reason: 'primero se usó el mouse');
      await gesto.removePointer();

      // Con el control remoto no hay cursor nativo: el aro es la única
      // referencia de dónde se está parado, así que tiene que volver.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(
        _opacidadDelAro(tester),
        1,
        reason: 'apenas se usa el D-pad el aro tiene que volver',
      );
    });
  });
}
