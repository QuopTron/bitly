// ─────────────────────────────────────────────────────────────
// caratula_util_test.dart — Fija las reglas de carátulas: una ruta
// local solo sirve si el archivo existe y no está vacío, y una ruta
// MUERTA nunca le gana a la carátula de respaldo (la remota).
// Parte del flujo: Mi Espacio, búsqueda, detalle (carátulas).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:bitly/shared/utilidades/portada/caratula_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late String archivoVivo;
  late String archivoVacio;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('bitly_caratulas');
    archivoVivo = '${temp.path}${Platform.pathSeparator}viva.jpg';
    archivoVacio = '${temp.path}${Platform.pathSeparator}vacia.jpg';
    File(archivoVivo).writeAsBytesSync([1, 2, 3, 4]);
    File(archivoVacio).writeAsBytesSync([]);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  const urlRemota = 'https://i.scdn.co/image/ab67616d000082c1bbd45c8d';

  group('caratulaLocalUsable', () {
    test('acepta un archivo que existe y tiene contenido', () {
      expect(caratulaLocalUsable(archivoVivo), isTrue);
    });

    test('rechaza un archivo de 0 bytes (guardado a medias)', () {
      expect(caratulaLocalUsable(archivoVacio), isFalse);
    });

    test('rechaza una ruta que ya no está en disco', () {
      final borrada = '${temp.path}${Platform.pathSeparator}no_esta.jpg';
      expect(caratulaLocalUsable(borrada), isFalse);
    });

    test('rechaza null, vacío y URLs', () {
      expect(caratulaLocalUsable(null), isFalse);
      expect(caratulaLocalUsable(''), isFalse);
      expect(caratulaLocalUsable(urlRemota), isFalse);
    });
  });

  group('esRutaDeArchivo', () {
    test('distingue archivos locales de URLs', () {
      expect(esRutaDeArchivo(urlRemota), isFalse);
      expect(esRutaDeArchivo('http://127.0.0.1:55009/cover/x.jpg'), isFalse);
      expect(esRutaDeArchivo(archivoVivo), isTrue);
      expect(esRutaDeArchivo(r'C:\covers\x.jpg'), isTrue);
      expect(esRutaDeArchivo(r'\\servidor\covers\x.jpg'), isTrue);
      expect(esRutaDeArchivo(''), isFalse);
    });
  });

  group('mejorCaratula', () {
    test('prefiere la remota cuando la local está MUERTA', () {
      final muerta = '${temp.path}${Platform.pathSeparator}no_esta.jpg';
      expect(mejorCaratula(muerta, urlRemota), urlRemota);
    });

    test('prefiere la local cuando el archivo existe', () {
      expect(mejorCaratula(archivoVivo, urlRemota), archivoVivo);
    });

    test('usa la remota cuando la carátula propia viene vacía', () {
      expect(mejorCaratula('', urlRemota), urlRemota);
      expect(mejorCaratula(null, urlRemota), urlRemota);
    });

    test('sin respaldo, una local muerta no devuelve nada', () {
      final muerta = '${temp.path}${Platform.pathSeparator}no_esta.jpg';
      expect(mejorCaratula(muerta, null), isNull);
      expect(mejorCaratula(muerta, ''), isNull);
    });

    test('sin nada que mostrar devuelve null', () {
      expect(mejorCaratula(null, null), isNull);
      expect(mejorCaratula('', '  '), isNull);
    });

    test('la URL propia se conserva aunque haya respaldo', () {
      expect(mejorCaratula(urlRemota, archivoVivo), urlRemota);
    });
  });
}
