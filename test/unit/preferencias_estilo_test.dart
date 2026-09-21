// preferencias_estilo_test.dart — Fija lo importante del estilo con cover:
// que el diseño de fábrica sea el monocromático (sin color de carátula), que
// la intensidad se acote a 0..1, que el guardado VIEJO de booleanos migre sin
// que nadie pierda lo que había elegido, y que el tinte de las cards use el
// color PURO del cover (la atenuación va en la opacidad de la capa, para que
// la foto no se borre al mover el control).
//
// Es lo que protege el cambio de los 5 interruptores al slider: si la
// migración se rompe, todos los que ya tenían Spotify vuelven a Normal sin
// enterarse.

import 'dart:math' as math;

import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo_json.dart';
import 'package:bitly/shared/utilidades/formato/comun/formato/estilo_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Distancia de color entre dos colores en escala 0..255 (0 = iguales).
/// `Color.r/g/b` son 0..1, así que se escala para leer los umbrales en
/// unidades de color.
double distancia(Color a, Color b) {
  final dr = (a.r - b.r) * 255, dg = (a.g - b.g) * 255, db = (a.b - b.b) * 255;
  return math.sqrt((dr * dr + dg * dg + db * db) / 3);
}

void main() {
  group('modelo', () {
    test('el diseño de fábrica es Normal (sin color de cover)', () {
      const p = PreferenciasEstilo.normal;
      expect(p.esNormal, isTrue);
      expect(p.niveles, everyElement(0.0));
      expect(p.general, 0);
      expect(p.esUniforme, isTrue);
    });

    test('la intensidad se acota entre 0 y 1', () {
      final p = const PreferenciasEstilo()
          .conNivel(ComponenteEstilo.cardsCancion, 5)
          .conNivel(ComponenteEstilo.cardsGrilla, -2);
      expect(p.cardsCancion, 1);
      expect(p.cardsGrilla, 0);
      expect(p.fondoPrincipal, 0, reason: 'no toca los otros componentes');
    });

    test('el general es el valor común, o el promedio si personalizó', () {
      expect(PreferenciasEstilo.completo.general, 1);
      expect(PreferenciasEstilo.completo.esUniforme, isTrue);

      final mezcla = const PreferenciasEstilo()
          .conNivel(ComponenteEstilo.cardsCancion, 1)
          .conNivel(ComponenteEstilo.cardsGrilla, 0.5);
      expect(mezcla.esUniforme, isFalse);
      expect(mezcla.general, closeTo(0.3, 0.001));
      expect(mezcla.esNormal, isFalse);
    });

    test('guardar y leer devuelve lo mismo', () {
      final original = const PreferenciasEstilo()
          .conNivel(ComponenteEstilo.cardsCancion, 0.4)
          .conNivel(ComponenteEstilo.fondosModals, 1);
      final leido = PreferenciasEstiloJson.decodificar(
        PreferenciasEstiloJson.codificar(original),
      );
      expect(leido.cardsCancion, 0.4);
      expect(leido.fondosModals, 1);
      expect(leido.fondoPrincipal, 0);
    });

    test('el guardado viejo de booleanos migra (true = 1, false = 0)', () {
      // Así se guardaba antes del slider: 5 booleanos.
      const viejo =
          '{"cardsCancion":true,"cardsGrilla":true,'
          '"fondoPrincipal":false,"fondoReproductor":true,'
          '"fondosModals":false}';
      final p = PreferenciasEstiloJson.decodificar(viejo);
      expect(p.cardsCancion, 1);
      expect(p.cardsGrilla, 1);
      expect(p.fondoReproductor, 1);
      expect(p.fondoPrincipal, 0);
      expect(p.fondosModals, 0);
      expect(p.esNormal, isFalse, reason: 'no pierde lo que había elegido');
    });

    test('un guardado roto deja el estilo Normal', () {
      for (final roto in ['', 'no es json', '[]', '{"cardsCancion":"x"}']) {
        final p = PreferenciasEstiloJson.decodificar(roto);
        expect(p.esNormal, isTrue, reason: 'con "$roto" debe quedar Normal');
      }
    });
  });

  group('acento de la capa de tinte', () {
    const cover = Color(0xFF1DB954);

    test('sin intensidad no hay tinte (la card queda del tema)', () {
      expect(EstiloHelper.acentoDeTinte(cover, 0), isNull);
      expect(EstiloHelper.acentoDeTinte(null, 1), isNull);
    });

    test('con cualquier intensidad el tinte es el color PURO del cover', () {
      // La atenuación es la opacidad de la capa, no una mezcla: mezclar el
      // color hacia el fondo ensuciaba el tono y al 1% dejaba un gris plano
      // encima de la carátula.
      expect(EstiloHelper.acentoDeTinte(cover, 0.01), cover);
      expect(EstiloHelper.acentoDeTinte(cover, 0.5), cover);
      expect(EstiloHelper.acentoDeTinte(cover, 1), cover);
    });
  });

  group('el color del cover que se pinta', () {
    const fondoOscuro = Color(0xFF121212);
    const fondoLuz = Color(0xFFF5F5F5);
    // Los covers reales no son colorinches: oscuros, grises y recién ahí vivos.
    const covers = [
      Color(0xFF3C2228),
      Color(0xFF5A5A5A),
      Color(0xFF1E2F52),
      Color(0xFFB04652),
    ];

    test('cualquier cover queda VISIBLE sobre el fondo', () {
      for (final acento in covers) {
        for (final fondo in const [fondoOscuro, fondoLuz]) {
          final pintado = EstiloHelper.colorDeCover(acento, fondo);
          expect(
            distancia(pintado, fondo),
            greaterThan(35),
            reason:
                'con el cover $acento sobre $fondo el control no tendría qué '
                'mostrar: el color quedaría casi igual al fondo',
          );
        }
      }
    });

    test('la mezcla apagada de antes NO alcanzaba', () {
      // Así se pintaba el tinte antes del arreglo: el color crudo mezclado
      // sobre el fondo. Con un cover oscuro quedaba pegadísimo al fondo, que
      // es exactamente el "no hace bien del 1 al 100" que se reportó.
      const acento = Color(0xFF3C2228);
      final apagado = Color.lerp(fondoOscuro, acento, 0.45)!;
      expect(distancia(apagado, fondoOscuro), lessThan(35));
    });

    test('el recorrido es 1:1: cada 10% avanza lo mismo', () {
      // El control NO tiene curva: la capa de tinte entra con el nivel tal
      // cual, así que el efecto pintado al 10% es la décima parte del total y
      // al 50% es la mitad. Sin tramos muertos ni cambios concentrados.
      const acento = Color(0xFF3C2228); // cover oscuro, el peor caso
      final pintado = EstiloHelper.colorDeCover(acento, fondoOscuro);
      double compuesto(double nivel) =>
          distancia(Color.lerp(fondoOscuro, pintado, nivel)!, fondoOscuro);

      final total = compuesto(1);
      expect(total, greaterThan(35), reason: 'el recorrido total se nota');
      for (var i = 1; i <= 10; i++) {
        expect(
          compuesto(i / 10),
          moreOrLessEquals(total * i / 10, epsilon: 0.001),
          reason:
              'al ${i * 10}% tiene que estar pintado justo esa fracción del '
              'efecto, ni menos ni más',
        );
      }
    });
  });

  group('desenfoque del fondo según el control', () {
    test('con el diseño de fábrica queda el sigma del perfil', () {
      expect(EstiloHelper.sigmaPorNivel(26, 0), 26);
      expect(EstiloHelper.sigmaPorNivel(48, 0), 48);
    });

    test('sube con la intensidad: la carátula se va desenfocando', () {
      var anterior = -1.0;
      for (var i = 0; i <= 100; i++) {
        final v = EstiloHelper.sigmaPorNivel(26, i / 100);
        expect(v, greaterThan(anterior), reason: 'deja de crecer al $i%');
        expect(v, lessThanOrEqualTo(EstiloHelper.topeSigma(26)));
        anterior = v;
      }
      // El extremo tiene que MOVER: si sólo subiera un pelo, el efecto no se
      // vería y daría igual el control.
      expect(EstiloHelper.sigmaPorNivel(26, 1), greaterThan(26 * 1.3));
    });

    test('en gama baja (sin presupuesto) no hay desenfoque', () {
      // El perfil de gama baja da sigma 0 y ahí no se paga ni un filtro.
      expect(EstiloHelper.sigmaPorNivel(0, 0), 0);
      expect(EstiloHelper.sigmaPorNivel(0, 1), 0);
      expect(EstiloHelper.topeSigma(0), 0);
    });

    test('el tope siempre alcanza al sigma pedido (si no, no se vería)', () {
      // Es el bug que esto evita: el sigma se recortaba al tope del perfil, así
      // que subir la intensidad no desenfocaba nada.
      for (final base in [6.0, 12.0, 26.0, 48.0]) {
        expect(
          EstiloHelper.sigmaPorNivel(base, 1),
          lessThanOrEqualTo(EstiloHelper.topeSigma(base)),
          reason: 'con base $base el tope recortaría el efecto',
        );
        expect(EstiloHelper.topeSigma(base), greaterThanOrEqualTo(base));
      }
    });
  });

  group('cruce de velos de las cards', () {
    test('los extremos son exactamente los valores de siempre', () {
      expect(EstiloHelper.mezclar(0.45, 0.20, 0), 0.45);
      expect(EstiloHelper.mezclar(0.45, 0.20, 1), 0.20);
    });

    test('a mitad de camino queda a mitad de mezcla', () {
      expect(EstiloHelper.mezclar(0.45, 0.20, 0.5), closeTo(0.325, 0.0001));

      const normal = Color(0xFF000000);
      const conColor = Color(0xFFFFFFFF);
      expect(
        EstiloHelper.mezclarColor(normal, conColor, 0.5),
        Color.lerp(normal, conColor, 0.5),
      );
    });
  });
}
