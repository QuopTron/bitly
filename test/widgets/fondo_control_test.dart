// fondo_control_test.dart — Mide el control de intensidad en los DOS fondos que
// no son cards: el ambiente de la Home (fondoPrincipal) y el del reproductor
// (fondoReproductor). Fija lo pedido: es 1:1 —al 10% hay 10% de color— y cada
// fondo responde SÓLO a su componente.
//
// Monta los widgets REALES (FondoAmbiente y FondoAmbientalReproductor): si
// alguien vuelve a meter una curva en uno de los dos, acá salta.

import 'package:bitly/app/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias_estilo.dart';
import 'package:bitly/features/reproductor/pagina/reproductor_pagina.dart';
import 'package:bitly/shared/widgets/fondos/atenuado_por_nivel.dart';
import 'package:bitly/shared/widgets/fondos/fondo_ambiente.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cover = 'https://ejemplo.com/tapa.jpg';
  const fondo = Color(0xFF121212);
  late ValueNotifier<PreferenciasEstilo> prefs;

  setUpAll(() {
    prefs = ValueNotifier(PreferenciasEstilo.normal);
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(prefs);
    di.sl.registerSingleton<ValueNotifier<PerfilRendimiento>>(
      ValueNotifier(PerfilRendimiento.alto),
    );
  });

  setUp(() => prefs.value = PreferenciasEstilo.normal);

  Widget app(Widget hijo) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 300, height: 300, child: hijo)),
  );

  /// Monta un fondo y lee sus tres capas: carátula, color del cover y velo.
  Future<({double foto, double color, double velo})> medir(
    WidgetTester tester,
    Widget fondoWidget,
  ) async {
    await tester.pumpWidget(app(fondoWidget));
    await tester.pump();

    final capas =
        tester
            .widgetList<AtenuadoPorNivel>(find.byType(AtenuadoPorNivel))
            .toList();
    expect(capas, hasLength(2), reason: 'el fondo es carátula + color');
    // De las cajas planas del fondo sólo valen la base opaca y el velo: el
    // color del cover también es un ColoredBox, pero va DENTRO de la capa
    // atenuada (se descarta por su ancestro), y las de opacidad 0 no pintan
    // nada (son marcadores internos de las carátulas).
    final cajas =
        find
            .byType(ColoredBox)
            .evaluate()
            .where(
              (e) =>
                  e.findAncestorWidgetOfExactType<AtenuadoPorNivel>() == null,
            )
            .map((e) => (e.widget as ColoredBox).color.a)
            .where((a) => a > 0)
            .toList();
    expect(cajas, hasLength(2), reason: 'la base opaca y el velo del tema');
    return (foto: capas[0].opacidad, color: capas[1].opacidad, velo: cajas[1]);
  }

  Widget home() =>
      const FondoAmbiente(coverUrl: cover, isDark: true, bgColor: fondo);

  Widget reproductor() => const FondoAmbientalReproductor(
    coverUrl: cover,
    esOscuro: true,
    colorFondo: fondo,
  );

  /// El control entero, paso a paso, sobre un fondo concreto.
  Future<void> medirRampa(
    WidgetTester tester,
    Widget Function() fondoWidget,
    ComponenteEstilo componente, {
    required double veloNormal,
    required double veloColor,
  }) async {
    for (var i = 0; i <= 10; i++) {
      final n = i / 10;
      prefs.value = const PreferenciasEstilo().conNivel(componente, n);
      final m = await medir(tester, fondoWidget());
      expect(
        m.foto,
        moreOrLessEquals(1 - n, epsilon: 0.001),
        reason: 'la carátula al ${i * 10}% no está 1:1',
      );
      expect(
        m.color,
        moreOrLessEquals(n, epsilon: 0.001),
        reason: 'el color del cover al ${i * 10}% no está 1:1',
      );
      expect(
        m.velo,
        moreOrLessEquals(
          veloNormal + (veloColor - veloNormal) * n,
          epsilon: 0.001,
        ),
        reason: 'el velo al ${i * 10}% no cruza lineal',
      );
    }
  }

  testWidgets('Home: el control es 1:1 de punta a punta', (tester) async {
    await medirRampa(
      tester,
      home,
      ComponenteEstilo.fondoPrincipal,
      veloNormal: 0.66,
      veloColor: 0.34,
    );
  });

  testWidgets('Reproductor: el control es 1:1 de punta a punta', (
    tester,
  ) async {
    await medirRampa(
      tester,
      reproductor,
      ComponenteEstilo.fondoReproductor,
      veloNormal: 0.66,
      veloColor: 0.34,
    );
  });

  testWidgets('cada fondo responde SÓLO a su componente', (tester) async {
    prefs.value = const PreferenciasEstilo()
        .conNivel(ComponenteEstilo.fondoPrincipal, 1)
        .conNivel(ComponenteEstilo.fondoReproductor, 0);

    // La Home queda sólo con el color del cover…
    final enHome = await medir(tester, home());
    expect(enHome.foto, 0);
    expect(enHome.color, 1);
    expect(enHome.velo, moreOrLessEquals(0.34, epsilon: 0.001));

    // …y el reproductor intacto, sin una gota de color.
    final enRepro = await medir(tester, reproductor());
    expect(enRepro.foto, 1);
    expect(enRepro.color, 0);
    expect(enRepro.velo, moreOrLessEquals(0.66, epsilon: 0.001));
  });
}
