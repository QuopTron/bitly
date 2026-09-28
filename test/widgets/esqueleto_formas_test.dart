// ─────────────────────────────────────────────────────────────
// esqueleto_formas_test.dart — Formas con nombre de esqueleto
// (EsqueletoEtiqueta / EsqueletoMarca) y el color que usan cuando
// el hueco no está sobre el fondo sino sobre un color.
//
// Por qué existe: estas dos formas reemplazaron a los spinners que
// quedaban en las acciones de Ajustes. Lo valioso de ellas no es el
// shimmer (que ya estaba en EsqueletoCarga) sino DOS cosas que se
// rompen en silencio: la FORMA (una barra donde va un texto, un
// cuadrado donde va un ícono — si se cambia, el layout salta al
// terminar de cargar) y el color cuando van encima de un botón
// relleno, donde el shimmer del tema (blanco al 6%) es invisible.
//
// Se lee el `Container` del bloque en vez de comparar píxeles: la
// forma está en el tamaño y el radio, y eso es exactamente el
// contrato. Con el modo fluido prendido el bloque queda con color
// plano, así que el color también se puede leer.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/shared/utilidades/plataforma/pantalla/efectos_app.dart';
import 'package:bitly/shared/widgets/esqueletos/esqueleto_carga.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    // Sin shimmer: el bloque se pinta con un color plano, legible desde el
    // `decoration`. Con la animación prendida, el color vive en un gradiente.
    EfectosApp.modoFluido.value = true;
    // Es estado GLOBAL: si una prueba lo deja prendido, la siguiente (y la
    // suite entera) pierde el shimmer sin darse cuenta.
    addTearDown(() => EfectosApp.modoFluido.value = false);
  });

  Widget app(Widget hijo) => MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    home: Scaffold(body: Center(child: hijo)),
  );

  Container bloque(WidgetTester tester) =>
      tester.widget<Container>(find.byType(Container));

  BoxDecoration deco(Container c) => c.decoration! as BoxDecoration;

  BorderRadius radio(Container c) => deco(c).borderRadius! as BorderRadius;

  /// Monta el hijo y deja que el listener de efectos lo repinte.
  Future<void> montar(WidgetTester tester, Widget hijo) async {
    await tester.pumpWidget(app(hijo));
    await tester.pump();
  }

  testWidgets('la etiqueta es una barra del tamaño pedido, pastilla por defecto', (
    tester,
  ) async {
    await montar(tester, const EsqueletoEtiqueta(ancho: 80, alto: 14));

    final c = bloque(tester);
    expect(c.constraints!.maxWidth, 80);
    expect(c.constraints!.maxHeight, 14);
    // Pastilla: el radio es la mitad del alto.
    expect(radio(c).topLeft.x, 7);
  });

  testWidgets('la etiqueta respeta el radio del botón donde va', (tester) async {
    await montar(
      tester,
      const EsqueletoEtiqueta(ancho: 80, alto: 14, radioBorde: 4),
    );

    // El botón de "Limpiar" tiene esquinas de 4: la barra no puede quedar más
    // redonda que el botón que reemplaza.
    expect(radio(bloque(tester)).topLeft.x, 4);
  });

  testWidgets('la marca es un cuadrado del lado pedido', (tester) async {
    await montar(tester, const EsqueletoMarca(lado: 20));

    final c = bloque(tester);
    expect(c.constraints!.maxWidth, 20);
    expect(c.constraints!.maxHeight, 20);
    // Cuadrado apenas redondeado (30%), no un círculo.
    expect(radio(c).topLeft.x, 6);
  });

  testWidgets('una marca redonda es un badge redondo', (tester) async {
    await montar(tester, const EsqueletoMarca(lado: 36, radioBorde: 18));

    expect(radio(bloque(tester)).topLeft.x, 18);
  });

  testWidgets('sobre un botón relleno el bloque cambia de color', (tester) async {
    await montar(tester, const EsqueletoEtiqueta(ancho: 90, alto: 16));
    final enElFondo = deco(bloque(tester)).color;

    await montar(
      tester,
      const EsqueletoEtiqueta(ancho: 90, alto: 16, sobreColor: true),
    );
    final sobreElColor = deco(bloque(tester)).color;

    // Es el punto de `sobreColor`: el blanco al 6% del tema, encima de un
    // verde o un rojo, no se ve. Y tiene que verse MÁS, no distinto y ya.
    expect(enElFondo, Colors.white.withValues(alpha: 0.06));
    expect(sobreElColor, isNot(enElFondo));
    expect(sobreElColor!.a, greaterThan(enElFondo!.a));
  });

  testWidgets('sin sobreColor el bloque sigue siendo el del tema', (tester) async {
    // El default NO puede cambiar: todos los esqueletos que ya existían (feed,
    // detalle, estadísticas) siguen con el color de siempre.
    await montar(tester, const EsqueletoCarga(ancho: 40, alto: 10));

    expect(deco(bloque(tester)).color, Colors.white.withValues(alpha: 0.06));
  });
}
