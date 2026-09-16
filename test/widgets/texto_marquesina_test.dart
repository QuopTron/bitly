// Test de TextoMarquesina: es lo que arregla que la letra larga del karaoke
// se cortara con "…". Debe desplazarse cuando no entra y quedarse quieta
// cuando entra (sin tickers de más).

import 'package:bitly/shared/widgets/texto/texto_marquesina.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Desplazamiento horizontal actual del contenido (0 si no se movió).
double _desplazamiento(WidgetTester tester) {
  var menor = 0.0;
  for (final t in tester.widgetList<Transform>(find.byType(Transform))) {
    final x = t.transform.storage[12];
    if (x < menor) menor = x;
  }
  return menor;
}

Future<void> _montar(
  WidgetTester tester, {
  required String texto,
  double ancho = 140,
  bool activo = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: ancho,
            child: DefaultTextStyle(
              style: const TextStyle(fontSize: 20),
              child: TextoMarquesina(
                span: TextSpan(text: texto),
                activo: activo,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // El arranque real se difiere al frame siguiente.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('el texto que entra queda quieto', (tester) async {
    await _montar(tester, texto: 'Corto');
    await tester.pump(const Duration(milliseconds: 900));
    expect(_desplazamiento(tester), 0);
    expect(find.textContaining('Corto'), findsOneWidget);
  });

  testWidgets('el texto que no entra se desplaza', (tester) async {
    await _montar(
      tester,
      texto: 'hola somos nosotros los que cantamos toda la cancion completa',
    );
    final inicio = _desplazamiento(tester);
    await tester.pump(const Duration(milliseconds: 700));
    final despues = _desplazamiento(tester);
    expect(despues, lessThan(inicio));
    // No se recorta: el texto entero sigue en el árbol.
    expect(
      find.textContaining('completa', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('inactivo no anima aunque desborde', (tester) async {
    await _montar(
      tester,
      texto: 'hola somos nosotros los que cantamos toda la cancion completa',
      activo: false,
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(_desplazamiento(tester), 0);
  });
}
