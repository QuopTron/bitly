// ─────────────────────────────────────────────────────────────
// preferencias_apariencia_test.dart — Fija lo importante de las
// preferencias de diseño: que el diseño de FÁBRICA sea el de la app
// actual, que los valores se acoten y que sobrevivan al guardado.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/modelos/usuario/preferencias_apariencia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el diseño de fábrica deja la app como está', () {
    const p = PreferenciasApariencia.deFabrica;
    expect(p.bordeMiniplayer, BordeMiniplayer.suave);
    expect(p.espacioX, 1);
    expect(p.espacioY, 1);
    expect(p.radioCards, 14);
    expect(p.esDeFabrica, isTrue);
  });

  test('los valores se acotan al rango admitido', () {
    final p = const PreferenciasApariencia()
        .copiarCon(espacioX: 9, espacioY: -3, radioCards: 999);
    expect(p.espacioX, PreferenciasApariencia.maxEspacio);
    expect(p.espacioY, PreferenciasApariencia.minEspacio);
    expect(p.radioCards, PreferenciasApariencia.maxRadio);
    expect(p.esDeFabrica, isFalse);
  });

  test('guardar y leer devuelve lo mismo', () {
    final original = const PreferenciasApariencia().copiarCon(
      bordeMiniplayer: BordeMiniplayer.marcado,
      espacioX: 0.5,
      espacioY: 0,
      radioCards: 4,
    );
    final leido =
        PreferenciasApariencia.desdeJsonString(original.toJsonString());
    expect(leido.bordeMiniplayer, BordeMiniplayer.marcado);
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

  test('una clave de borde desconocida cae al borde suave', () {
    expect(BordeMiniplayer.desdeClave('inventado'), BordeMiniplayer.suave);
    expect(BordeMiniplayer.desdeClave(null), BordeMiniplayer.suave);
  });
}
