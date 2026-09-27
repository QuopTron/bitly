// ─────────────────────────────────────────────────────────────
// imagen_portada_glow_test.dart — Fija que el glow de la portada respete el
// interruptor global de desenfoques (EfectosApp).
//
// Por qué importa: el glow es una sombra con `MaskFilter.blur`, o sea una
// máscara difusa del tamaño de cada portada compuesta en cada frame. Es el
// costo que más crece con la cantidad de tarjetas en pantalla, y era el único
// punto de las tarjetas que NO consultaba el interruptor: el monitor apagaba
// los desenfoques midiendo el equipo real y cada portada seguía pagando su
// glow. Con el interruptor apagado el diseño debe mantenerse (imagen y borde
// redondeado), solo se suelta la sombra.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/shared/utilidades/plataforma/pantalla/efectos_app.dart';
import 'package:bitly/shared/widgets/tarjetas/portada/imagen_portada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contenedores del árbol que pintan una sombra (el glow).
Iterable<Container> _conSombra(WidgetTester tester) {
  return tester.widgetList<Container>(find.byType(Container)).where((c) {
    final d = c.decoration;
    return d is BoxDecoration && (d.boxShadow?.isNotEmpty ?? false);
  });
}

void main() {
  setUp(EfectosApp.reiniciar);
  tearDown(EfectosApp.reiniciar);

  Widget montar({required Color? glow}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: ImagenPortada(
          ancho: 100,
          alto: 100,
          radioBorde: 12,
          colorGlow: glow,
          fallback: const SizedBox(width: 100, height: 100),
        ),
      ),
    ),
  );

  testWidgets('con efectos permitidos pinta el glow', (tester) async {
    await tester.pumpWidget(montar(glow: const Color(0xFFFF0000)));

    expect(_conSombra(tester), isNotEmpty);
    expect(find.byType(ClipRRect), findsWidgets, reason: 'sigue redondeada');
  });

  testWidgets('sin desenfoques el glow desaparece y el diseño queda', (
    tester,
  ) async {
    // Es lo que hacen el perfil de gama baja y el monitor de frames.
    EfectosApp.aplicar(efectosPesados: false, sigmaMax: 0);

    await tester.pumpWidget(montar(glow: const Color(0xFFFF0000)));

    expect(
      _conSombra(tester),
      isEmpty,
      reason: 'la sombra con blur es el costo por tarjeta que hay que soltar',
    );
    expect(
      find.byType(ImagenPortada),
      findsOneWidget,
      reason: 'la portada se sigue mostrando: solo se suelta la sombra',
    );
    expect(find.byType(ClipRRect), findsWidgets, reason: 'sigue redondeada');
  });

  testWidgets('sin color de glow no hay sombra en ningún caso', (tester) async {
    await tester.pumpWidget(montar(glow: null));
    expect(_conSombra(tester), isEmpty);
  });
}
