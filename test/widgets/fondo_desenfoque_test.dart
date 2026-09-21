// fondo_desenfoque_test.dart — Mide el DESENFOQUE del fondo en el Home y en el
// reproductor: con el diseño de fábrica (0%) queda el sigma del perfil y a
// medida que sube el control la carátula se va desenfocando, hasta un tope
// propio que SIEMPRE alcanza al sigma pedido.
//
// Esa última parte es el bug que esto caza: el sigma se recortaba al tope del
// perfil de rendimiento, así que subir la intensidad no desenfocaba nada.
//
// También fija que en gama baja (sin presupuesto de desenfoque) no se pague
// ningún filtro, con control o sin él.

import 'dart:math' as math;

import 'package:bitly/app/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias_estilo.dart';
import 'package:bitly/features/reproductor/pagina/reproductor_pagina.dart';
import 'package:bitly/shared/utilidades/formato/estilo_helper.dart';
import 'package:bitly/shared/utilidades/plataforma/efectos_app.dart';
import 'package:bitly/shared/widgets/fondos/fondo_ambiente.dart';
import 'package:bitly/shared/widgets/vidrio/desenfoque_adaptativo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cover = 'https://ejemplo.com/tapa.jpg';
  const fondo = Color(0xFF121212);
  late ValueNotifier<PreferenciasEstilo> prefs;
  late double perfilSigma;

  setUpAll(() {
    prefs = ValueNotifier(PreferenciasEstilo.normal);
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(prefs);
    di.sl.registerSingleton<ValueNotifier<PerfilRendimiento>>(
      ValueNotifier(PerfilRendimiento.alto),
    );
    perfilSigma =
        di.sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque;
  });

  setUp(() {
    prefs.value = PreferenciasEstilo.normal;
    EfectosApp.reiniciar();
  });

  tearDown(EfectosApp.reiniciar);

  Widget app(Widget hijo) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 300, height: 300, child: hijo)),
  );

  /// El sigma que el fondo aplica DE VERDAD (ya recortado por su tope), o null
  /// si al 100% la carátula ya se fue del todo: ahí no hay nada que desenfocar.
  double? sigmaDe(WidgetTester tester) {
    final encontrados = find.byType(DesenfoqueHijo).evaluate();
    if (encontrados.isEmpty) return null;
    final d = encontrados.single.widget as DesenfoqueHijo;
    final tope = d.tope;
    return tope == null ? d.sigma : math.min(d.sigma, tope);
  }

  Future<double?> montar(WidgetTester tester, Widget hijo) async {
    await tester.pumpWidget(app(hijo));
    await tester.pump();
    return sigmaDe(tester);
  }

  const home = FondoAmbiente(coverUrl: cover, isDark: true, bgColor: fondo);
  const reproductor = FondoAmbientalReproductor(
    coverUrl: cover,
    esOscuro: true,
    colorFondo: fondo,
  );

  group('fondo del Home', () {
    testWidgets('con 0% queda el sigma de fábrica y sube desde ahí', (
      tester,
    ) async {
      // El fondo del Home usa el menor entre el perfil y el tope global.
      final base = math.min(perfilSigma, EfectosApp.sigmaMaximo.value);
      prefs.value = PreferenciasEstilo.normal;
      expect(await montar(tester, home), moreOrLessEquals(base, epsilon: 0.01));

      var anterior = base;
      for (final n in [0.25, 0.5, 0.75]) {
        prefs.value = const PreferenciasEstilo().conNivel(
          ComponenteEstilo.fondoPrincipal,
          n,
        );
        final sigma = await montar(tester, home);
        expect(sigma, isNotNull, reason: 'la carátula tiene que seguir ahí');
        expect(
          sigma!,
          greaterThan(anterior),
          reason: 'al ${(n * 100).round()}% la carátula no se desenfocó más',
        );
        expect(sigma, lessThanOrEqualTo(EstiloHelper.topeSigma(base)));
        anterior = sigma;
      }

      // Al 100% la carátula ya se fue del todo: no queda nada que desenfocar.
      prefs.value = PreferenciasEstilo.completo;
      expect(await montar(tester, home), isNull);
    });
  });

  group('fondo del reproductor', () {
    testWidgets('con 0% queda el sigma de fábrica y sube desde ahí', (
      tester,
    ) async {
      prefs.value = PreferenciasEstilo.normal;
      expect(
        await montar(tester, reproductor),
        moreOrLessEquals(perfilSigma, epsilon: 0.01),
      );

      var anterior = perfilSigma;
      for (final n in [0.25, 0.5, 0.75]) {
        prefs.value = const PreferenciasEstilo().conNivel(
          ComponenteEstilo.fondoReproductor,
          n,
        );
        final sigma = await montar(tester, reproductor);
        expect(sigma, isNotNull, reason: 'la carátula tiene que seguir ahí');
        expect(sigma!, greaterThan(anterior), reason: 'no crece al $n');
        // El tope propio tiene que ALCANZAR al sigma pedido: si el desenfoque
        // se recortara al del perfil, subir la intensidad no haría nada.
        expect(sigma, lessThanOrEqualTo(EstiloHelper.topeSigma(perfilSigma)));
        anterior = sigma;
      }

      prefs.value = PreferenciasEstilo.completo;
      expect(await montar(tester, reproductor), isNull);
    });
  });

  testWidgets('en gama baja no se paga ningún filtro', (tester) async {
    // El perfil de gama baja apaga el desenfoque: ni con el control al máximo
    // puede quedar un ImageFiltered a pantalla completa.
    EfectosApp.aplicar(efectosPesados: false, sigmaMax: 0);
    // A mitad de camino: la carátula está presente y el control al máximo
    // pediría el sigma más grande, que es el caso caro.
    prefs.value = const PreferenciasEstilo()
        .conNivel(ComponenteEstilo.fondoPrincipal, 0.5)
        .conNivel(ComponenteEstilo.fondoReproductor, 0.5);

    await montar(tester, home);
    expect(find.byType(ImageFiltered), findsNothing);

    await montar(tester, reproductor);
    expect(find.byType(ImageFiltered), findsNothing);
  });
}
