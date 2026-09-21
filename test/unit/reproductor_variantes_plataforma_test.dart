// ─────────────────────────────────────────────────────────────
// reproductor_variantes_plataforma_test.dart — Vigila la regla "el
// reproductor se separa por plataforma": hay TRES variantes (celular,
// PC y TV) y el control de volumen vive SÓLO en PC y TV.
//
// Por qué existe: en un teléfono el volumen lo manejan las teclas del
// aparato; un deslizador en pantalla sería un segundo volumen (el de
// la app) peleando con el del sistema. Si alguien copia el control a
// la variante de celular, o deja de elegir variante y vuelve a un
// cuerpo único, este test falla. Es el mismo patrón que
// modales_centralizados_test.dart: leer el código y exigir el contrato.
// Parte del flujo: reproductor (elección de variante).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cada variante y si le TOCA el control de volumen.
const _variantes = <String, bool>{
  'lib/features/reproductor/vistas/reproductor_movil.dart': false,
  'lib/features/reproductor/vistas/reproductor_escritorio.dart': true,
  'lib/features/reproductor/vistas/reproductor_tv.dart': true,
};

/// El selector que elige variante y el marco que las registra como part.
const _selector = 'lib/features/reproductor/vistas/vista_reproductor.dart';
const _marco = 'lib/features/reproductor/pagina/base/reproductor_pagina.dart';

String _leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

/// Saca los comentarios: mencionar algo en la cabecera no es usarlo.
String _soloCodigo(String fuente) => fuente
    .split('\n')
    .where((linea) => !linea.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('existen las tres variantes del reproductor', () {
    for (final ruta in _variantes.keys) {
      expect(File(ruta).existsSync(), isTrue, reason: 'falta $ruta');
    }
  });

  test('las tres son `part` del marco (no copias sueltas)', () {
    for (final ruta in _variantes.keys) {
      expect(
        _soloCodigo(_leer(ruta)),
        contains('part of'),
        reason: '$ruta tiene que ser parte de la library del reproductor',
      );
    }
    final marco = _leer(_marco);
    for (final ruta in _variantes.keys) {
      final nombre = ruta.split('/').last;
      expect(
        marco,
        contains(nombre),
        reason: 'el marco no registra $nombre como part',
      );
    }
  });

  test('el volumen va SÓLO en PC y TV, nunca en celular', () {
    final conVolumen = <String>[];
    for (final entrada in _variantes.entries) {
      final codigo = _soloCodigo(_leer(entrada.key));
      final loUsa = codigo.contains('VolumenReproductor');
      expect(
        loUsa,
        entrada.value,
        reason:
            entrada.value
                ? '${entrada.key} tendría que montar VolumenReproductor'
                : '${entrada.key} NO puede montar el volumen: en el aparato lo '
                    'manejan las teclas del sistema',
      );
      if (loUsa) conVolumen.add(entrada.key);
    }
    expect(
      conVolumen,
      hasLength(2),
      reason: 'el volumen es de PC y TV, ni uno más ni uno menos',
    );
  });

  test('el selector pregunta PRIMERO por TV', () {
    final codigo = _soloCodigo(_leer(_selector));
    final tv = codigo.indexOf('usarLayoutTv');
    final pc = codigo.indexOf('usarLayoutEscritorio');
    expect(tv, greaterThan(-1), reason: 'el selector no mira TV');
    expect(pc, greaterThan(-1), reason: 'el selector no mira PC');
    expect(
      tv,
      lessThan(pc),
      reason:
          'una tele ancha también entra en el layout de escritorio: TV se '
          'pregunta primero o la tele usa el diseño de PC',
    );
  });
}
