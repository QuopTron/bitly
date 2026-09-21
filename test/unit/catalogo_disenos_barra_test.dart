// ─────────────────────────────────────────────────────────────
// catalogo_disenos_barra_test.dart — Fija lo importante del cofre de
// PALETAS: que la primera sea el regalo que trae la app (llega con la
// v1.0.0 y no tiñe nada, así el cofre no cambia cómo se ve la app), que
// las horas y la versión abran lo que tienen que abrir, que ninguna paleta
// quede sin color, y que el contador de regalos cuente bien.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/modelos/usuario/catalogo_disenos_barra_lista.dart';
import 'package:bitly/core/modelos/usuario/preferencias_apariencia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la primera paleta es el regalo de la v1.0.0 y no tiñe nada', () {
    final regalo = catalogoDisenosBarra.first;
    // Si esto cambia, abrir el cofre dejaría la app distinta a como viene.
    expect(regalo.desbloqueo, DesbloqueoBarra.libre);
    expect(regalo.llegoConVersion, '1.0.0');
    expect(regalo.tienePaleta, isFalse, reason: 'el vidrio de fábrica');
    // Y es la que viene puesta por defecto en las dos barras.
    expect(regalo.id, PreferenciasApariencia.deFabrica.disenoNavbarId);
    expect(regalo.id, PreferenciasApariencia.deFabrica.disenoMiniplayerId);
  });

  test('la versión se lee como número comparable', () {
    expect(versionEnNumero('0.9.22'), 922);
    expect(versionEnNumero('0.9.22+3'), 922, reason: 'ignora el build');
    expect(versionEnNumero('1.0.0'), 10000);
    expect(versionLegible(923), '0.9.23');
    // Lo ilegible queda en 0: no desbloquea nada por versión.
    for (final roto in [null, '', '9.22', 'a.b.c', '0.9.x']) {
      expect(versionEnNumero(roto), 0, reason: 'con "$roto" no hay versión');
    }
  });

  test('sin horas ni versión solo se abre el regalo', () {
    final abiertos =
        catalogoDisenosBarra
            .where((d) => disenoDesbloqueado(d, horas: 0, version: 0))
            .map((d) => d.id)
            .toList();
    expect(abiertos, ['paleta_regalo_100']);
  });

  test('las horas abren el diseño de su nivel', () {
    final d = disenoPorId('paleta_menta')!; // pide 100 h
    expect(disenoDesbloqueado(d, horas: 99, version: 0), isFalse);
    expect(disenoDesbloqueado(d, horas: 100, version: 0), isTrue);
    expect(disenoDesbloqueado(d, horas: 9000, version: 0), isTrue);
    // Y una forma también se abre por horas, no solo las paletas.
    final forma = disenoPorId('pastilla')!; // pide 50 h
    expect(disenoDesbloqueado(forma, horas: 49, version: 0), isFalse);
    expect(disenoDesbloqueado(forma, horas: 50, version: 0), isTrue);
  });

  test('el cofre mezcla FORMAS y COLORES, y cada uno trae lo suyo', () {
    // Las formas: cambian las esquinas de arriba y no tiñen nada.
    final recto = disenoPorId('esquinas_rectas')!;
    expect(recto.tieneForma, isTrue);
    expect(recto.radioArriba, 0, reason: 'recto de verdad');
    expect(recto.tienePaleta, isFalse, reason: 'una forma no cambia el color');

    final pastilla = disenoPorId('pastilla')!;
    expect(pastilla.radioArriba, PreferenciasApariencia.maxRadioBarra);
    expect(
      pastilla.radioArriba,
      greaterThan(disenoPorId('muy_redondeada')!.radioArriba!),
    );

    // El contorno también es un diseño, sin forma ni color.
    final marcado = disenoPorId('contorno_marcado')!;
    expect(marcado.tieneTrazo, isTrue);
    expect(marcado.tieneForma, isFalse);
    expect(marcado.tienePaleta, isFalse);

    // Las paletas, al revés: tiñen y no tocan la forma.
    final aurora = disenoPorId('paleta_aurora')!;
    expect(aurora.tienePaleta, isTrue);
    expect(aurora.tieneForma, isFalse, reason: 'una paleta no cambia la forma');
  });

  test('el regalo de actualización pide la versión que lo trae', () {
    final d = disenoPorId('paleta_fuego')!; // pide 0.9.23
    expect(disenoDesbloqueado(d, horas: 0, version: 922), isFalse);
    expect(disenoDesbloqueado(d, horas: 0, version: 923), isTrue);
    // Y sobrevive a que la versión no se pueda leer.
    expect(disenoDesbloqueado(d, horas: 0, version: 0), isFalse);
  });

  test('los adornos son OLAS o una calcomanía, no otra curvatura', () {
    // Olas: el borde ondula y NO trae radio (eso lo mueve el control).
    final olas = disenoPorId('olas')!;
    expect(olas.adorno, AdornoBarra.olas);
    expect(olas.tieneAdorno, isTrue);
    expect(olas.tieneForma, isFalse, reason: 'el radio lo mueve el control');
    expect(olas.tienePaleta, isFalse, reason: 'no toca el color');

    // Las calcomanías: traen un id que el widget sabe dibujar.
    for (final id in const ['sticker_destello', 'sticker_nota']) {
      final d = disenoPorId(id)!;
      expect(d.tieneSticker, isTrue, reason: '$id no trae calcomanía');
      expect(d.sticker, isNotEmpty);
      expect(d.tieneAdorno, isFalse);
      expect(d.tienePaleta, isFalse);
    }
  });

  test('la intensidad de las olas se traduce en cantidad (2 a 6)', () {
    expect(PreferenciasApariencia.olasDe(0), 2);
    expect(PreferenciasApariencia.olasDe(1), 6);
    expect(PreferenciasApariencia.olasDe(0.5), 4);
    // Fuera de rango se acota: el control nunca pide cero olas.
    expect(PreferenciasApariencia.olasDe(-3), 2);
    expect(PreferenciasApariencia.olasDe(9), 6);
  });

  test('todo diseño que se abre trae forma, color o contorno', () {
    for (final d in catalogoDisenosBarra) {
      if (d.desbloqueo == DesbloqueoBarra.libre) continue;
      expect(
        d.traeAlgo,
        isTrue,
        reason: '${d.id} se abre y no cambia absolutamente nada',
      );
      for (final c in d.paleta) {
        // Opacos a propósito: la mezcla sobre el fondo la hace el helper, así
        // una paleta no puede dejar la barra transparente.
        expect(c >> 24, 0xFF, reason: '${d.id} tiene un color con alpha');
      }
      expect(d.paleta.length, lessThanOrEqualTo(3));
      // Una forma fuera del rango del control dejaría el slider sin poder
      // volver a ese valor: la pastilla es el máximo.
      if (d.tieneForma) {
        expect(
          d.radioArriba,
          inInclusiveRange(0, PreferenciasApariencia.maxRadioBarra),
        );
      }
    }
  });

  test('los ids viejos de esquinas siguen teniendo dueño', () {
    // Las preferencias ya guardadas no pueden quedar sin diseño en el cofre.
    expect(disenoPorId('fabrica_navbar')!.id, 'paleta_regalo_100');
    expect(disenoPorId('fabrica_mini')!.id, 'paleta_regalo_100');
    // Las formas viejas existen de nuevo: se resuelven solas y conservan su
    // forma (por eso NO están en el mapa de herederos).
    expect(disenoPorId('pastilla')!.id, 'pastilla');
    expect(disenoPorId('esquinas_rectas')!.radioArriba, 0);
    expect(disenoPorId('esquinas_doradas')!.id, 'paleta_oro');
    expect(disenoPorId('inventado'), isNull);
    expect(disenoPorId(PreferenciasApariencia.disenoPersonalizado), isNull);
  });

  test('el contador de regalos cuenta solo lo abierto y no abierto', () {
    // Con muchas horas y la versión nueva se abre todo menos el regalo.
    final todos =
        catalogoDisenosBarra
            .where((d) => d.desbloqueo != DesbloqueoBarra.libre)
            .length;
    expect(
      regalosDisponibles(horas: 99999, version: 10000, vistos: const {}).length,
      todos,
    );

    // Al abrir uno, deja de contarse.
    final uno = disenoPorId('paleta_aurora')!.id;
    expect(
      regalosDisponibles(horas: 99999, version: 10000, vistos: {uno}).length,
      todos - 1,
    );

    // Recién arrancando no hay nada para abrir.
    expect(regalosDisponibles(horas: 0, version: 0, vistos: const {}), isEmpty);
  });

  test('el cofre se muestra en dos secciones y no pierde ningún diseño', () {
    final mostrados =
        [...disenosCofreBarra, ...coloresCofreBarra].map((d) => d.id).toList();
    expect(mostrados, catalogoDisenosBarra.map((d) => d.id).toList());
    // Cada sección agrupa lo suyo: en Colores todo tiñe, y en Diseños no.
    for (final d in coloresCofreBarra) {
      expect(
        d.tienePaleta,
        isTrue,
        reason: '${d.id} está en Colores y no tiñe',
      );
    }
    for (final d in disenosCofreBarra) {
      expect(d.tienePaleta, isFalse, reason: '${d.id} está en Diseños y tiñe');
    }
    expect(disenosCofreBarra.length, greaterThan(1), reason: 'hay secciones');
  });

  test('ningún id se repite (el cofre no muestra duplicados)', () {
    final ids = catalogoDisenosBarra.map((d) => d.id).toSet();
    expect(ids.length, catalogoDisenosBarra.length);
  });
}
