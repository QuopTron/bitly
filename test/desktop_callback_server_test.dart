import 'dart:convert';
import 'dart:io';

import 'package:bitly/core/servicios/servidor_callback_escritorio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Flutter test blocks real HTTP by default; the callback server needs real
  // loopback networking.
  HttpOverrides.global = null;

  group('ServidorCallbackEscritorio', () {
    test('binds on a loopback port and is ready', () async {
      final server = ServidorCallbackEscritorio.instance;
      final ok = await server.garantizarIniciado();
      expect(ok, isTrue);
      expect(server.estaListo, isTrue);
      expect(server.puerto, isNotNull);
    });

    test('delivers the grant from a GET request', () async {
      final server = ServidorCallbackEscritorio.instance;
      await server.garantizarIniciado();
      final port = server.puerto!;

      final future = server.esperarGrant(const Duration(seconds: 5));

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse(
              'http://127.0.0.1:$port/session-grant?cb_version=v2grant&grant=gr_test123'))
          .timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 5));
      final body = await response.transform(utf8.decoder).join();
      client.close();

      expect(response.statusCode, HttpStatus.ok);
      expect(body, contains('Verificación completada'));
      expect(await future, 'gr_test123');
    });

    test('delivers the grant from a MALFORMED query (bug de Windows)', () async {
      // La página de zarz concatena el grant con `?` aunque el callback ya
      // traiga `?cb_version=v2grant`. El parseo estricto por Uri no ve `grant`
      // y el modal quedaba abierto para siempre en Windows.
      final server = ServidorCallbackEscritorio.instance;
      await server.garantizarIniciado();
      final port = server.puerto!;

      final future = server.esperarGrant(const Duration(seconds: 5));

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:$port/session-grant'
              '?cb_version=v2grant?grant=gr_malformado'))
          .timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
      client.close();

      expect(response.statusCode, HttpStatus.ok);
      expect(await future, 'gr_malformado');
    });

    test('delivers the grant from a POST body (JSON)', () async {
      final server = ServidorCallbackEscritorio.instance;
      await server.garantizarIniciado();
      final port = server.puerto!;

      final future = server.esperarGrant(const Duration(seconds: 5));

      final client = HttpClient();
      final request =
          await client.postUrl(Uri.parse('http://127.0.0.1:$port/session-grant'));
      request.headers.contentType = ContentType.json;
      request.write('{"grant":"gr_desde_body"}');
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
      client.close();

      expect(response.statusCode, HttpStatus.ok);
      expect(await future, 'gr_desde_body');
    });

    test('no confunde un cuerpo JSON sin grant con un grant', () async {
      final server = ServidorCallbackEscritorio.instance;
      await server.garantizarIniciado();
      final port = server.puerto!;

      final client = HttpClient();
      final request =
          await client.postUrl(Uri.parse('http://127.0.0.1:$port/session-grant'));
      request.headers.contentType = ContentType.json;
      request.write('{"ok":true,"mensaje":"hola"}');
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
      client.close();

      expect(response.statusCode, HttpStatus.badRequest);
    });

    test('completes with null on cancel (skip)', () async {
      final server = ServidorCallbackEscritorio.instance;
      await server.garantizarIniciado();

      final future = server.esperarGrant(const Duration(seconds: 10));
      server.cancelar();
      expect(await future, isNull);
    });

    test('times out with null', () async {
      final server = ServidorCallbackEscritorio.instance;
      await server.garantizarIniciado();

      final future = server.esperarGrant(const Duration(milliseconds: 200));
      expect(await future, isNull);
    });
  });
}