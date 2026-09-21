// Test de TextoLineaLetra: la regla es que la letra se ve ENTERA y CENTRADA.
//
// El bug que esto fija: en el karaoke una línea larga se recortaba ("hola somos
// nosotros…") y después se hacía desfilar con una marquesina, donde solo se veía
// una ventana del texto y el movimiento era por tiempo (no seguía a la voz).
// Ahora la línea envuelve centrada y no se recorta nunca.
//
// Se mide sobre el párrafo real (RenderParagraph): texto completo pintado, sin
// recorte (`didExceedMaxLines`), centrado y ocupando más de un renglón cuando no
// entra en el ancho.

import 'package:bitly/shared/widgets/texto/texto_linea_letra.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _larga =
    'hola somos nosotros los que cantamos toda la cancion completa '
    'y ademas seguimos cantando el resto del verso sin perdernos nada';

Future<void> _montar(
  WidgetTester tester, {
  required double ancho,
  required String texto,
}) async {
  tester.view.physicalSize = Size(ancho, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: ancho,
            child: DefaultTextStyle(
              style: const TextStyle(fontSize: 20),
              child: TextoLineaLetra(span: TextSpan(text: texto)),
            ),
          ),
        ),
      ),
    ),
  );
}

RenderParagraph _parrafo(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.byType(RichText).first);

void main() {
  testWidgets('la línea larga envuelve y no recorta nada', (tester) async {
    await _montar(tester, ancho: 260, texto: _larga);

    final p = _parrafo(tester);
    expect(p.didExceedMaxLines, isFalse, reason: 'no debe recortarse');
    // El texto completo está pintado (sin "…" ni corte silencioso).
    expect(p.text.toPlainText(), _larga);
    // Envolvió: ocupa más de un renglón.
    expect(p.size.height, greaterThan(28));
  });

  testWidgets('el texto queda CENTRADO', (tester) async {
    await _montar(tester, ancho: 260, texto: _larga);
    expect(_parrafo(tester).textAlign, TextAlign.center);
  });

  testWidgets('la línea corta queda en un renglón', (tester) async {
    await _montar(tester, ancho: 400, texto: 'hola');

    final p = _parrafo(tester);
    expect(p.didExceedMaxLines, isFalse);
    expect(p.size.height, lessThan(30));
  });
}
