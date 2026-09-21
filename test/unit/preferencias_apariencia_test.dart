// ─────────────────────────────────────────────────────────────
// preferencias_apariencia_test.dart — Fija lo importante de las
// preferencias de diseño: que el diseño de FÁBRICA sea el de la app
// actual, que los valores se acoten y que sobrevivan al guardado.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el diseño de fábrica deja la app como está', () {
    const p = PreferenciasApariencia.deFabrica;
    expect(p.trazoBarra, TrazoBarra.suave);
    expect(p.radioNavbar, 20, reason: 'el navbar de fábrica tiene 20');
    expect(p.radioMiniplayer, 8, reason: 'el miniplayer de fábrica tiene 8');
    // La paleta de regalo (la que trae la app, sin tinte) en las dos barras.
    expect(p.disenoNavbarId, 'paleta_regalo_100');
    expect(p.disenoMiniplayerId, 'paleta_regalo_100');
    expect(p.espacioX, 1);
    expect(p.espacioY, 1);
    expect(p.radioCards, 14);
    expect(p.esDeFabrica, isTrue);
  });

  test('los valores se acotan al rango admitido', () {
    final p = const PreferenciasApariencia().copiarCon(
      espacioX: 9,
      espacioY: -3,
      radioCards: 999,
    );
    expect(p.espacioX, PreferenciasApariencia.maxEspacio);
    expect(p.espacioY, PreferenciasApariencia.minEspacio);
    expect(p.radioCards, PreferenciasApariencia.maxRadio);
    expect(p.esDeFabrica, isFalse);
  });

  test('guardar y leer devuelve lo mismo', () {
    final original = const PreferenciasApariencia().copiarCon(
      trazoBarra: TrazoBarra.marcado,
      radioNavbar: 33,
      radioMiniplayer: 12,
      disenoNavbarId: 'pastilla',
      regalosVistos: const ['esquinas_rectas'],
      espacioX: 0.5,
      espacioY: 0,
      radioCards: 4,
    );
    final leido = PreferenciasApariencia.desdeJsonString(
      original.toJsonString(),
    );
    expect(leido.trazoBarra, TrazoBarra.marcado);
    expect(leido.radioNavbar, 33);
    expect(leido.radioMiniplayer, 12);
    expect(leido.disenoNavbarId, 'pastilla');
    expect(leido.regalosVistos, ['esquinas_rectas']);
    expect(leido.espacioX, 0.5);
    expect(leido.espacioY, 0);
    expect(leido.radioCards, 4);
  });

  test('un valor guardado roto no rompe el arranque', () {
    for (final roto in ['', 'no es json', '{"espacioX":"x"}', '[]']) {
      final p = PreferenciasApariencia.desdeJsonString(roto);
      expect(p.esDeFabrica, isTrue, reason: 'con "$roto" debe quedar fábrica');
    }
  });

  test('el control general deja los dos ejes iguales (uniforme)', () {
    // Así guarda el control general: los dos ejes al mismo valor.
    final p = const PreferenciasApariencia().copiarCon(
      espacioX: 0.4,
      espacioY: 0.4,
    );
    expect(p.separacionUniforme, isTrue);

    // Y al separar uno solo, deja de ser uniforme.
    final q = p.copiarCon(espacioY: 0.9);
    expect(q.separacionUniforme, isFalse);
    expect(q.espacioX, 0.4, reason: 'el otro eje no se toca');
  });

  test('la línea divisoria aparece sola al juntar (extremo 0)', () {
    const fab = PreferenciasApariencia.deFabrica;
    expect(fab.opacidadLineaX, 0, reason: 'de fábrica no hay línea');
    expect(fab.opacidadLineaY, 0);

    final juntos = const PreferenciasApariencia().copiarCon(
      espacioX: 0,
      espacioY: 0,
    );
    expect(juntos.opacidadLineaX, 1, reason: 'pegadas: línea plena');
    expect(juntos.opacidadLineaY, 1);

    // A mitad del tramo final ya está a medias.
    final medio = const PreferenciasApariencia().copiarCon(espacioY: 0.1);
    expect(medio.opacidadLineaY, closeTo(0.5, 0.001));
    // Fuera del tramo, apagada.
    final lejos = const PreferenciasApariencia().copiarCon(espacioY: 0.5);
    expect(lejos.opacidadLineaY, 0);
  });

  test('una clave de trazo desconocida cae al trazo suave', () {
    expect(TrazoBarra.desdeClave('inventado'), TrazoBarra.suave);
    expect(TrazoBarra.desdeClave(null), TrazoBarra.suave);
  });

  test('el redondeo de las barras se acota al rango', () {
    final p = const PreferenciasApariencia().copiarCon(
      radioNavbar: 999,
      radioMiniplayer: -5,
    );
    expect(p.radioNavbar, PreferenciasApariencia.maxRadioBarra);
    expect(p.radioMiniplayer, PreferenciasApariencia.minRadioBarra);
  });

  test('las preferencias viejas (bordeMiniplayer) no se pierden', () {
    // Lo guardado por versiones anteriores usa la clave vieja y el valor
    // viejo 'sin_borde': tiene que llegar igual al trazo nuevo.
    final leido = PreferenciasApariencia.desdeJsonString(
      '{"bordeMiniplayer":"sin_borde"}',
    );
    expect(leido.trazoBarra, TrazoBarra.sinTrazo);

    final suave = PreferenciasApariencia.desdeJsonString(
      '{"bordeMiniplayer":"marcado"}',
    );
    expect(suave.trazoBarra, TrazoBarra.marcado);
  });
}
