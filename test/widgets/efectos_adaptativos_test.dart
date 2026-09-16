// efectos_adaptativos_test.dart — Con el perfil de gama baja ningún widget
// puede pintar un desenfoque de GPU (es lo que congela la app en un Helio G).
//
// Se conecta con: efectos_app + contenedor_vidrio + desenfoque_adaptativo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/shared/utilidades/plataforma/efectos_app.dart';
import 'package:bitly/shared/widgets/vidrio/contenedor_vidrio.dart';
import 'package:bitly/shared/widgets/vidrio/desenfoque_adaptativo.dart';

Future<void> _montar(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  tearDown(EfectosApp.reiniciar);

  group('gama baja (efectos apagados)', () {
    setUp(() => EfectosApp.aplicar(efectosPesados: false, sigmaMax: 0));

    testWidgets('el contenedor de vidrio no compone BackdropFilter', (
      tester,
    ) async {
      await _montar(
        tester,
        const ContenedorVidrio(
          blurSigma: 24,
          bgColor: Colors.black,
          child: SizedBox(width: 40, height: 40),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(DesenfoqueAdaptativo), findsOneWidget,
          reason: 'el widget sigue ahí, pero no aplica blur');
    });

    testWidgets('un desenfoque de hijo devuelve el hijo intacto', (
      tester,
    ) async {
      await _montar(
        tester,
        const DesenfoqueHijo(
          sigma: 24,
          child: SizedBox(key: Key('hijo'), width: 40, height: 40),
        ),
      );

      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byKey(const Key('hijo')), findsOneWidget);
    });
  });

  group('gama media/alta (efectos encendidos)', () {
    setUp(() => EfectosApp.aplicar(efectosPesados: true, sigmaMax: 26));

    testWidgets('el vidrio sí desenfoca', (tester) async {
      await _montar(
        tester,
        const ContenedorVidrio(
          blurSigma: 18,
          bgColor: Colors.black,
          child: SizedBox(width: 40, height: 40),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('el sigma se recorta al tope del perfil (nunca lo supera)', (
      tester,
    ) async {
      // Tope 0 con efectos encendidos: el clamp tiene que dejar el hijo sin
      // blur, no aplicar el sigma pedido.
      EfectosApp.aplicar(efectosPesados: true, sigmaMax: 0);
      await _montar(
        tester,
        const DesenfoqueHijo(
          sigma: 40,
          child: SizedBox(width: 40, height: 40),
        ),
      );

      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('el desenfoque de hijo sí se aplica', (tester) async {
      await _montar(
        tester,
        const DesenfoqueHijo(
          sigma: 20,
          child: SizedBox(width: 40, height: 40),
        ),
      );

      expect(find.byType(ImageFiltered), findsOneWidget);
    });
  });
}
