import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/shared/widgets/indicador_descarga.dart';

void main() {
  group('EstadoDescarga', () {
    test('none is default', () {
      expect(EstadoDescarga.ninguno.index, 0);
    });

    test('queued is second', () {
      expect(EstadoDescarga.enCola.index, 1);
    });

    test('inProgress is third', () {
      expect(EstadoDescarga.enProgreso.index, 2);
    });

    test('completed is fourth', () {
      expect(EstadoDescarga.completado.index, 3);
    });
  });

  group('IndicadorDescarga', () {
    testWidgets('renders nothing specific in none state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IndicadorDescarga(estado: EstadoDescarga.ninguno),
          ),
        ),
      );

      // The widget renders a SizedBox with a dot inside
      expect(find.byType(IndicadorDescarga), findsOneWidget);
    });

    testWidgets('renders inProgress ring', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const IndicadorDescarga(
              estado: EstadoDescarga.enProgreso,
            ),
          ),
        ),
      );

      expect(find.byType(IndicadorDescarga), findsOneWidget);
    });

    testWidgets('renders completed ring', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IndicadorDescarga(estado: EstadoDescarga.completado),
          ),
        ),
      );

      expect(find.byType(IndicadorDescarga), findsOneWidget);
    });

    testWidgets('accepts custom tamano', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IndicadorDescarga(estado: EstadoDescarga.ninguno, tamano: 24),
          ),
        ),
      );

      final indicator = tester.widget<IndicadorDescarga>(find.byType(IndicadorDescarga));
      expect(indicator.tamano, 24);
    });

    testWidgets('uses default tamano of 8', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const IndicadorDescarga(),
          ),
        ),
      );

      final indicator = tester.widget<IndicadorDescarga>(find.byType(IndicadorDescarga));
      expect(indicator.tamano, IndicadorDescarga.tamanoPorDefecto);
    });
  });
}

