// Tests del escalado de calidad de los reintentos de descarga.
//
// Lo que importa: que el primer intento respete lo que pidió el usuario, que
// cada reintento baje un escalón (y no se quede pidiendo lo mismo que falló) y
// que NUNCA suba la calidad por encima de lo configurado.

import 'package:bitly/core/servicios/descargas/escalado_calidad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el primer intento no fuerza calidad (respeta los ajustes)', () {
    expect(
      calidadParaIntento(forzada: null, calidadAjustes: 'FLAC', intento: 1),
      isNull,
    );
    expect(
      calidadParaIntento(forzada: null, calidadAjustes: 'MP3_320', intento: 1),
      isNull,
    );
  });

  test('sin pérdida cae 320 y después 128', () {
    expect(
      calidadParaIntento(forzada: null, calidadAjustes: 'FLAC', intento: 2),
      'MP3_320',
    );
    expect(
      calidadParaIntento(forzada: null, calidadAjustes: 'LOSSLESS', intento: 3),
      'MP3_128',
    );
  });

  test('desde 320 un reintento pide 128', () {
    expect(
      calidadParaIntento(forzada: null, calidadAjustes: 'MP3_320', intento: 2),
      'MP3_128',
    );
  });

  test('desde 128 los reintentos se quedan en 128 (no hay escalón más bajo)', () {
    expect(
      calidadParaIntento(forzada: null, calidadAjustes: 'MP3_128', intento: 2),
      'MP3_128',
    );
    expect(
      calidadParaIntento(forzada: null, calidadAjustes: 'LOW', intento: 5),
      'MP3_128',
    );
  });

  test('nunca sube la calidad por encima de lo pedido', () {
    expect(
      calidadParaIntento(forzada: 'MP3_128', calidadAjustes: 'FLAC', intento: 2),
      'MP3_128',
    );
    expect(
      calidadParaIntento(forzada: 'MP3_320', calidadAjustes: 'FLAC', intento: 2),
      'MP3_128',
    );
  });

  test('una calidad forzada se conserva en el primer intento', () {
    expect(
      calidadParaIntento(forzada: 'MP3_320', calidadAjustes: 'FLAC', intento: 1),
      'MP3_320',
    );
  });
}
