// ─────────────────────────────────────────────────────────────
// caratulas_mi_espacio_test.dart — Fija el respaldo de carátulas de
// Mi Espacio: la del íte manda si sirve, la de la biblioteca local
// entra cuando el registro perdió la portada o el nombre, y el
// limpiador de rutas de like descarta los archivos que ya no están.
// Parte del flujo: Mi Espacio (tarjetas de las 4 pestañas).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:bitly/core/cache/estado/estado_like.dart';
import 'package:bitly/features/mi_espacio/datos/datos_mi_espacio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('caratulaDeItem', () {
    test('usa la carátula de la biblioteca cuando el ítem no tiene', () {
      const bib = DatoBiblioteca(
        nombre: 'Un Verano Sin Ti',
        caratula: 'https://cdn/a.jpg',
      );
      expect(caratulaDeItem(null, bib), 'https://cdn/a.jpg');
      expect(caratulaDeItem('', bib), 'https://cdn/a.jpg');
    });

    test('la del ítem gana sobre la de la biblioteca', () {
      const bib = DatoBiblioteca(caratula: 'https://cdn/a.jpg');
      expect(caratulaDeItem('https://cdn/b.jpg', bib), 'https://cdn/b.jpg');
    });

    test('sin biblioteca ni carátula propia no inventa nada', () {
      expect(caratulaDeItem('', null), isNull);
      expect(caratulaDeItem(null, null), isNull);
    });
  });

  group('nombreDeItem', () {
    test('el nombre del ítem manda', () {
      const bib = DatoBiblioteca(nombre: 'Álbum');
      expect(nombreDeItem('Otro', bib), 'Otro');
    });

    test('cae al nombre de la biblioteca si el del ítem viene vacío', () {
      const bib = DatoBiblioteca(nombre: 'DeBÍ TiRAR MÁS FOToS');
      expect(nombreDeItem('', bib), 'DeBÍ TiRAR MÁS FOToS');
      expect(nombreDeItem('   ', bib), 'DeBÍ TiRAR MÁS FOToS');
    });

    test('sin biblioteca usa el respaldo (el id) y nunca queda vacío raro', () {
      expect(nombreDeItem('', null, respaldo: '5k79fl'), '5k79fl');
      expect(nombreDeItem(null, null), '');
    });
  });

  group('limpiarRutaCaratulaLocal', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('bitly_like'));
    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('conserva una carátula local que existe de verdad', () {
      final ruta = '${temp.path}${Platform.pathSeparator}cover.jpg';
      File(ruta).writeAsBytesSync([1, 2, 3]);
      expect(limpiarRutaCaratulaLocal(ruta), ruta);
    });

    test('descarta la ruta muerta (el like ya no tapa la portada de red)', () {
      final muerta = '${temp.path}${Platform.pathSeparator}vieja.jpg';
      expect(limpiarRutaCaratulaLocal(muerta), isNull);
    });

    test('descarta el loopback legacy del escritorio', () {
      const legacy = 'http://127.0.0.1:55009/cover/abc.jpg';
      expect(limpiarRutaCaratulaLocal(legacy), isNull);
    });

    test('descarta null y vacío', () {
      expect(limpiarRutaCaratulaLocal(null), isNull);
      expect(limpiarRutaCaratulaLocal(''), isNull);
    });
  });
}
