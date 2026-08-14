import 'dart:convert';
import 'dart:io';

import 'package:bitly/backend/services/desktop_callback_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Flutter test blocks real HTTP by default; the callback server needs real
  // loopback networking.
  HttpOverrides.global = null;

  group('DesktopCallbackServer', () {
    test('binds on a loopback port and is ready', () async {
      final server = DesktopCallbackServer.instance;
      final ok = await server.ensureStarted();
      expect(ok, isTrue);
      expect(server.isReady, isTrue);
      expect(server.port, isNotNull);
    });

    test('delivers the grant from a GET request', () async {
      final server = DesktopCallbackServer.instance;
      await server.ensureStarted();
      final port = server.port!;

      final future = server.waitForGrant(const Duration(seconds: 5));

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

    test('completes with null on cancel (skip)', () async {
      final server = DesktopCallbackServer.instance;
      await server.ensureStarted();

      final future = server.waitForGrant(const Duration(seconds: 10));
      server.cancel();
      expect(await future, isNull);
    });

    test('times out with null', () async {
      final server = DesktopCallbackServer.instance;
      await server.ensureStarted();

      final future = server.waitForGrant(const Duration(milliseconds: 200));
      expect(await future, isNull);
    });
  });
}
