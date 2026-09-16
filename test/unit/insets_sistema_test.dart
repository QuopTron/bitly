// insets_sistema_test.dart — El inset inferior del sistema (menú de navegación
// del celular: atrás / home / recientes) tiene que reservarse SIEMPRE y una
// sola vez.
//
// Qué bug fija: en un celular con las 3 teclas del sistema, las hojas modales
// y el espaciador de las páginas de detalle se anclan al borde FÍSICO de la
// pantalla. Si nadie reserva el alto del menú de navegación, sus últimos
// botones quedan debajo de él y el usuario no los puede tocar.
//
// También fija que NO se reserve dos veces: dentro de un `SafeArea` el inset ya
// fue consumido, así que el helper tiene que devolver 0 y no duplicar el
// espacio (el "padding falso" que el usuario reporta).
//
// Se conecta con: lib/shared/utilidades/plataforma/insets_sistema.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/shared/utilidades/plataforma/insets_sistema.dart';

void main() {
  group('insetInferiorSistema', () {
    testWidgets('devuelve el alto del menú de navegación del celular', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      // Celular con las 3 teclas del sistema: 144 px físicos / 3 = 48 dp.
      tester.view.viewPadding = const FakeViewPadding(bottom: 144);
      tester.view.padding = const FakeViewPadding(bottom: 144);
      addTearDown(tester.view.reset);

      double leido = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              leido = insetInferiorSistema(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(leido, closeTo(48.0, 0.01));
    });

    testWidgets('con navegación por gestos el inset es 0', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      double leido = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              leido = insetInferiorSistema(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(leido, 0);
    });
  });

  group('ReservaInferiorSistema', () {
    testWidgets('levanta el contenido justo el alto del menú', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      tester.view.viewPadding = const FakeViewPadding(bottom: 144);
      tester.view.padding = const FakeViewPadding(bottom: 144);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                ReservaInferiorSistema(
                  child: SizedBox(
                    key: const Key('contenido'),
                    height: 40,
                    width: double.infinity,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // El borde inferior del contenido tiene que quedar a 48 dp del fondo
      // físico, nunca pegado a él (ahí están las 3 teclas del sistema).
      final caja = tester.getRect(find.byKey(const Key('contenido')));
      final pantalla = tester.getRect(find.byType(MaterialApp));
      expect(pantalla.bottom - caja.bottom, closeTo(48.0, 0.01));
    });

    testWidgets('dentro de un SafeArea no reserva dos veces', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      tester.view.viewPadding = const FakeViewPadding(bottom: 144);
      tester.view.padding = const FakeViewPadding(bottom: 144);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const Spacer(),
                  ReservaInferiorSistema(
                    child: SizedBox(
                      key: const Key('contenido'),
                      height: 40,
                      width: double.infinity,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // SafeArea ya reservó los 48 dp: el contenido queda a 48 del fondo, no a
      // 96 (que sería la doble reserva / "padding falso").
      final caja = tester.getRect(find.byKey(const Key('contenido')));
      final pantalla = tester.getRect(find.byType(MaterialApp));
      expect(pantalla.bottom - caja.bottom, closeTo(48.0, 0.01));

      // Y el helper dentro del SafeArea devuelve 0.
      double leido = -1;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, _) => SafeArea(
            child: Builder(
              builder: (inner) {
                leido = insetInferiorSistema(inner);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(leido, 0);
    });
  });
}
