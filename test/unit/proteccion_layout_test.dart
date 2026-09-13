// proteccion_layout_test.dart — Verifica la protección global de layout contra
// los dos ajustes de Android que rompían el diseño:
//
//   1. Accesibilidad → Tamaño de fuente (textScaler > 1): las cajas crecían y
//      los botones de avanzar quedaban fuera de alcance.
//   2. Pantalla → Tamaño de pantalla (más densidad = menos px lógicos): las
//      filas y grillas dejaban de entrar.
//
// Y el envoltorio que impide que un slide del setup desborde en pantallas
// bajas, que es el mismo fallo (no poder avanzar) pero en el setup.
//
// Se conecta con: shared/utilidades/plataforma/escala_texto.dart y
// shared/widgets/base/contenido_con_alto_minimo.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/shared/utilidades/plataforma/escala_texto.dart';
import 'package:bitly/shared/widgets/base/contenido_con_alto_minimo.dart';

/// Reporta por texto lo que ve el árbol protegido y contiene una fila que NO
/// entra en una pantalla angosta: si la protección fallara, Flutter tiraría un
/// overflow (excepción) y el test lo vería.
class _Sonda extends StatelessWidget {
  const _Sonda();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('ancho:${mq.size.width.toStringAsFixed(1)}'),
        Text('escala:${mq.textScaler.scale(10).toStringAsFixed(1)}'),
        Row(
          children: [
            for (var i = 0; i < 4; i++)
              const SizedBox(width: 80, height: 40),
          ],
        ),
      ],
    );
  }
}

Widget _protegida() => MaterialApp(
      home: Builder(
        builder: (context) =>
            protegerLayout(context: context, child: const _Sonda()),
      ),
    );

void main() {
  group('protección global de layout', () {
    testWidgets('acota el tamaño de fuente del sistema al máximo soportado',
        (tester) async {
      // 2.0 es el tope de Android en Accesibilidad → Tamaño de fuente.
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(_protegida());

      expect(tester.takeException(), isNull);
      // 10px de diseño escalados: nunca más de 1.3x.
      expect(find.text('escala:13.0'), findsOneWidget);
    });

    testWidgets('en una pantalla normal no cambia nada', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_protegida());

      expect(tester.takeException(), isNull);
      expect(find.text('ancho:400.0'), findsOneWidget,
          reason: 'una pantalla normal se usa tal cual, sin escalar');
    });

    testWidgets('con la densidad subida (menos px lógicos) no desborda',
        (tester) async {
      // Simula "Pantalla → Tamaño de pantalla" al máximo: el mismo teléfono
      // reporta 280px lógicos, donde una fila de 320px ya no entra.
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_protegida());

      expect(tester.takeException(), isNull,
          reason: 'la fila que no entraba debe escalarse, no desbordar');
      expect(find.text('ancho:320.0'), findsOneWidget,
          reason: 'la app recibe el ancho de diseño mínimo soportado');
    });
  });

  group('slide del setup con alto garantizado', () {
    testWidgets('en pantalla baja desplaza en vez de recortar el botón',
        (tester) async {
      tester.view.physicalSize = const Size(360, 420);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContenidoConAltoMinimo(
              altoMinimo: 560,
              // Spacer/Expanded exigen alto acotado: si el envoltorio no lo
              // garantizara, esto reventaría.
              child: Column(
                children: [
                  const Expanded(child: Center(child: Text('contenido'))),
                  const Text('Continuar'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // El botón arranca fuera de la vista…
      expect(tester.getRect(find.text('Continuar')).bottom, greaterThan(420));

      // …y se alcanza desplazando, en vez de quedar perdido.
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pump();
      expect(tester.getRect(find.text('Continuar')).bottom, lessThanOrEqualTo(420),
          reason: 'el botón de continuar debe poder alcanzarse');
    });

    testWidgets('en pantalla alta usa el alto real, sin scroll', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContenidoConAltoMinimo(
              altoMinimo: 560,
              child: Column(
                children: [
                  const Expanded(child: Center(child: Text('contenido'))),
                  const Text('Continuar'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('Continuar')).bottom, lessThanOrEqualTo(800));
    });
  });
}
