// Prueba de RED de la traducción de letras: comprueba contra el traductor real
// que el servicio devuelve líneas traducidas y el idioma detectado.
//
// Va con guarda (BITLY_TRADUCCION_RED=1) porque depende de un servicio externo
// gratuito: la batería normal no puede quedar roja porque Google cambie algo.
//
//   BITLY_TRADUCCION_RED=1 flutter test test/unit/traduccion_letras_red_test.dart

import 'dart:io';

import 'package:bitly/core/servicios/traduccion/servicio_traduccion_letras.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final habilitado = Platform.environment['BITLY_TRADUCCION_RED'] == '1';

  test(
    'traduce las líneas y detecta el idioma de origen',
    () async {
      final servicio = ServicioTraduccionLetras();
      final res = await servicio.traducir(
        lineas: ['Nunca es suficiente', '', 'Yo te quiero'],
        destino: 'en',
      );

      expect(res, isNotNull, reason: 'el traductor no respondió');
      expect(res!.idiomaOrigen, isNotEmpty);
      expect(res.lineas, hasLength(3));
      // La línea vacía queda vacía (es un silencio del karaoke).
      expect(res.lineas[1], isNull);
      expect(res.lineas[0], isNotEmpty);
      expect(res.lineas[2], isNotEmpty);
      // Y no vuelve el texto original: se tradujo de verdad.
      expect(res.lineas[0]!.toLowerCase(), isNot('nunca es suficiente'));
      // ignore: avoid_print
      print('origen=${res.idiomaOrigen} lineas=${res.lineas}');
    },
    skip:
        habilitado
            ? false
            : 'definí BITLY_TRADUCCION_RED=1 para la prueba de red',
  );

  test(
    'una letra LARGA (canción entera) se traduce completa, línea por línea',
    () async {
      // 44 líneas ~= una canción real. Es el caso que reportó el usuario: la
      // traducción no traía todo lo escrito cuando la letra era larga.
      final lineas = [
        for (var i = 1; i <= 44; i++)
          'Esta es la linea numero $i de la cancion',
      ];
      final servicio = ServicioTraduccionLetras();
      final res = await servicio.traducir(lineas: lineas, destino: 'en');

      expect(
        res,
        isNotNull,
        reason: 'el traductor no respondió con la letra larga',
      );
      expect(res!.lineas, hasLength(lineas.length));
      final vacias =
          res.lineas.where((l) => l == null || l.trim().isEmpty).length;
      expect(
        vacias,
        0,
        reason: 'quedaron líneas sin traducir: $vacias de ${lineas.length}',
      );
      // ignore: avoid_print
      print(
        'larga: ${res.lineas.length} líneas, '
        'primera=${res.lineas.first} ultima=${res.lineas.last}',
      );
    },
    skip:
        habilitado
            ? false
            : 'definí BITLY_TRADUCCION_RED=1 para la prueba de red',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
