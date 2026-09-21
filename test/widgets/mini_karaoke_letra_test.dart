// Test de MiniKaraokeLetra (la tira del karaoke traducido).
//
// Lo que se fija:
//  · el texto traducido se ve COMPLETO (una traducción larga envuelve, no se
//    recorta) — la misma regla que la letra original;
//  · el barrido enciende lo ya cantado y deja tenue lo que falta (con progreso
//    0 todo está tenue y con 1 todo encendido);
//  · la línea siguiente se muestra en su propio tono.

import 'package:bitly/shared/widgets/texto/mini_karaoke_letra.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _brillo = Color(0xFFFF0000);
const _tenue = Color(0xFF0000FF);
const _siguiente = Color(0xFF00FF00);

const _traduccionLarga =
    'hola somos nosotros los que cantamos toda la cancion completa y ademas '
    'seguimos cantando el resto del verso sin perdernos nada de nada';

Future<void> _montar(
  WidgetTester tester, {
  required String? actual,
  String? siguiente,
  double progreso = 0,
  double ancho = 280,
}) async {
  tester.view.physicalSize = Size(ancho, 400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: ancho,
            child: MiniKaraokeLetra(
              actual: actual,
              siguiente: siguiente,
              progreso: progreso,
              brillo: _brillo,
              tenue: _tenue,
              siguienteColor: _siguiente,
              tamanoFuente: 14,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Colores de todos los tramos de texto del párrafo (RichText).
List<Color?> _coloresDeTexto(WidgetTester tester) {
  final colores = <Color?>[];
  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    rt.text.visitChildren((span) {
      if (span is TextSpan && (span.text ?? '').isNotEmpty) {
        colores.add(span.style?.color);
      }
      return true;
    });
  }
  return colores;
}

void main() {
  testWidgets('la traducción larga se ve completa (no se recorta)', (
    tester,
  ) async {
    await _montar(tester, actual: _traduccionLarga);

    final p = tester.renderObject<RenderParagraph>(find.byType(RichText).first);
    expect(p.didExceedMaxLines, isFalse);
    expect(p.text.toPlainText(), _traduccionLarga);
    // Centrada, igual que la letra grande.
    expect(p.textAlign, TextAlign.center);
  });

  testWidgets('sin progreso todo el texto está tenue', (tester) async {
    await _montar(tester, actual: 'uno dos tres', progreso: 0);
    expect(_coloresDeTexto(tester), everyElement(_tenue));
  });

  testWidgets('con la línea terminada todo está encendido', (tester) async {
    await _montar(tester, actual: 'uno dos tres', progreso: 1);
    expect(_coloresDeTexto(tester), everyElement(_brillo));
  });

  testWidgets('el barrido parte la línea entre cantado y por cantar', (
    tester,
  ) async {
    await _montar(tester, actual: 'uno dos tres cuatro', progreso: 0.5);
    final colores = _coloresDeTexto(tester);
    expect(colores, contains(_brillo));
    expect(colores, contains(_tenue));
  });

  testWidgets('muestra la línea siguiente en su propio tono', (tester) async {
    await _montar(tester, actual: 'linea actual', siguiente: 'linea siguiente');

    expect(find.text('linea siguiente'), findsOneWidget);
    final p = tester.renderObject<RenderParagraph>(find.byType(RichText).last);
    expect(p.text.toPlainText(), 'linea siguiente');
    expect(p.text.style?.color, _siguiente);
  });

  testWidgets('sin traducción no ocupa lugar', (tester) async {
    await _montar(tester, actual: null);
    expect(find.byType(RichText), findsNothing);
  });
}
