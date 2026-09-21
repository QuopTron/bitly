// ─────────────────────────────────────────────────────────────
// portada_playlist_test.dart — Prueba que la foto elegida para una
// playlist se COPIE a la carpeta estable de la app y conserve su
// extensión (y que sin extensión use .jpg).
//
// Por qué existe: la portada se guardaba con la ruta que devuelve el
// selector de archivos, que en Android apunta a la CACHÉ del plugin
// (se puede borrar → portada muerta). Este test fija la copia.
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:bitly/shared/utilidades/portada/portada_playlist.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // El host de tests no tiene la implementación nativa de path_provider:
  // se simula su canal para que devuelva una carpeta temporal.
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('bitly_portada_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              call.method == 'getApplicationDocumentsDirectory'
                  ? docs.path
                  : null,
        );
  });

  tearDown(() {
    try {
      docs.deleteSync(recursive: true);
    } catch (_) {}
  });

  test(
    'copia la foto a la carpeta de portadas y conserva la extensión',
    () async {
      final origen = File('${docs.path}/foto.PNG')
        ..writeAsBytesSync([1, 2, 3, 4]);

      final copiada = await copiarPortadaDeArchivo(origen.path);

      expect(copiada, isNotNull);
      expect(copiada, contains(carpetaPortadas));
      expect(copiada!.toLowerCase().endsWith('.png'), isTrue);
      expect(File(copiada).readAsBytesSync(), [1, 2, 3, 4]);
      // La foto original queda donde estaba: solo se copia.
      expect(origen.existsSync(), isTrue);
    },
  );

  test('sin extensión conocida usa .jpg', () async {
    final ruta = await rutaNuevaPortada(docs.path, 'foto_sin_extension');

    expect(ruta.endsWith('.jpg'), isTrue);
    expect(ruta, contains(carpetaPortadas));
  });

  test('cada portada recibe un nombre distinto', () async {
    final primera = await rutaNuevaPortada(docs.path, 'a.png');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final segunda = await rutaNuevaPortada(docs.path, 'a.png');

    expect(primera == segunda, isFalse);
  });

  test('si el origen no existe devuelve null y no rompe', () async {
    final copiada = await copiarPortadaDeArchivo('${docs.path}/no_existe.jpg');

    expect(copiada, isNull);
  });
}
