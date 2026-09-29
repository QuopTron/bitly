// update_service_test.dart — Fija CÓMO detecta la app que hay una versión nueva.
//
// Por qué existe: la app y el sitio NO leen el repo del código (es privado y
// sus assets exigen token), sino el repo PÚBLICO espejo de releases
// (QuopTron/bitly-releases). De ahí sale la primera descarga que ve el usuario,
// así que si esta detección se rompe, el aviso de "hay versión nueva" deja de
// aparecer sin que nada crashee.
//
// Lo que se fija acá:
//   · el camino normal (/releases/latest) y la elección del asset de ESTA
//     plataforma,
//   · el respaldo por LISTA: cubre el caso en que el espejo creó una release
//     VIEJA más tarde (y `/latest` pasa a apuntar hacia atrás) y el caso en que
//     la última release no trae el binario de esta plataforma,
//   · que un error de red o un 404 no rompan nada (devuelve null).
//
// Nada de esto toca la red: el cliente HTTP se inyecta con MockClient.
//
// Se conecta con: features/ajustes/update/base/update_service.dart (+ update_assets).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bitly/features/ajustes/update/base/update_service.dart';

/// Assets que ESTA plataforma/máquina sí puede usar: uno por cada nombre
/// esperado, exactamente como los publica el workflow de release.
List<Map<String, dynamic>> _assetsDeLaPlataforma(String version) {
  return UpdateService.patronesAsset(version)
      .map(
        (n) => {
          'name': n,
          'size': 1000,
          'browser_download_url':
              'https://github.com/QuopTron/bitly-releases/releases/download/v$version/$n',
        },
      )
      .toList();
}

/// Un release falso de GitHub con la forma que devuelve la API.
Map<String, dynamic> _release(
  String version, {
  List<Map<String, dynamic>>? assets,
  bool draft = false,
  bool prerelease = false,
}) => {
  'tag_name': 'v$version',
  'name': 'Bitly $version',
  'body': 'Novedades de $version',
  'draft': draft,
  'prerelease': prerelease,
  'assets': assets ?? _assetsDeLaPlataforma(version),
};

/// Cliente HTTP falso: sirve `latest` en /releases/latest y `lista` en la
/// lista de releases. `latest` en null simula un 404 (repo sin releases).
http.Client _githubFalso({
  Map<String, dynamic>? latest,
  List<Map<String, dynamic>>? lista,
}) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/releases/latest')) {
      if (latest == null) return http.Response('{"message":"Not Found"}', 404);
      return http.Response(jsonEncode(latest), 200);
    }
    return http.Response(jsonEncode(lista ?? const []), 200);
  });
}

void main() {
  group('comparación de versiones', () {
    test('esMasNueva distingue mayor, igual y menor', () {
      expect(UpdateService.esMasNueva('0.9.29', '0.9.28'), isTrue);
      expect(UpdateService.esMasNueva('0.9.28', '0.9.28'), isFalse);
      expect(UpdateService.esMasNueva('0.9.27', '0.9.28'), isFalse);
      expect(UpdateService.esMasNueva('0.10.0', '0.9.99'), isTrue);
      // Tramo que falta = 0: 0.9 y 0.9.0 son la misma versión.
      expect(UpdateService.esMasNueva('0.9.0', '0.9'), isFalse);
    });

    test('una versión ilegible no dice "hay update"', () {
      expect(UpdateService.esMasNueva('v0.9.x', '0.9.28'), isNull);
      expect(UpdateService.compararVersiones('0.9.28', 'sin-version'), isNull);
    });
  });

  group('camino normal: /releases/latest', () {
    test('devuelve el asset de esta plataforma cuando hay versión nueva', () async {
      final service = UpdateService(
        cliente: _githubFalso(latest: _release('0.9.29')),
      );

      final info = await service.checkForUpdate(versionInstalada: '0.9.28');

      expect(info, isNotNull);
      expect(info!.version, '0.9.29');
      expect(info.nombreAsset, UpdateService.patronesAsset('0.9.29').first);
      expect(info.downloadUrl, contains('/v0.9.29/'));
      expect(info.body, contains('0.9.29'));
    });

    test('estando al día no ofrece nada', () async {
      final service = UpdateService(
        cliente: _githubFalso(latest: _release('0.9.28')),
      );
      expect(await service.checkForUpdate(versionInstalada: '0.9.28'), isNull);
    });

    test('un draft o un prerelease no cuentan como versión nueva', () async {
      final draft = UpdateService(
        cliente: _githubFalso(latest: _release('0.9.30', draft: true)),
      );
      expect(await draft.checkForUpdate(versionInstalada: '0.9.28'), isNull);

      final beta = UpdateService(
        cliente: _githubFalso(latest: _release('0.9.30', prerelease: true)),
      );
      expect(await beta.checkForUpdate(versionInstalada: '0.9.28'), isNull);
    });
  });

  group('respaldo por lista de releases', () {
    test('el espejo creó una release vieja después: igual encuentra la nueva',
        () async {
      // El caso real: en el repo público, "latest" es la release CREADA más
      // recientemente, no la de versión más alta. Si el espejo sube tarde una
      // release vieja, /latest apunta hacia atrás y sin respaldo la app diría
      // "no hay nada nuevo".
      final service = UpdateService(
        cliente: _githubFalso(
          latest: _release('0.9.20'),
          lista: [
            _release('0.9.20'),
            _release('0.9.31'),
            _release('0.9.29'),
          ],
        ),
      );

      final info = await service.checkForUpdate(versionInstalada: '0.9.28');

      expect(info, isNotNull);
      expect(info!.version, '0.9.31');
    });

    test('la última release no trae el binario de esta plataforma', () async {
      // Release de macOS mezclada en el mismo listado: para esta plataforma no
      // sirve, así que se ofrece la última que SÍ trae el asset correcto.
      final sinBinario = _release('0.9.31', assets: [
        {
          'name': 'Bitly-0.9.31-macos.dmg',
          'size': 10,
          'browser_download_url': 'https://github.com/x/Bitly-0.9.31-macos.dmg',
        },
      ]);

      final service = UpdateService(
        cliente: _githubFalso(
          latest: sinBinario,
          lista: [sinBinario, _release('0.9.29')],
        ),
      );

      final info = await service.checkForUpdate(versionInstalada: '0.9.28');

      expect(info, isNotNull);
      expect(info!.version, '0.9.29');
      expect(info.nombreAsset, UpdateService.patronesAsset('0.9.29').first);
    });

    test('sin nada más nuevo en la lista, no inventa una actualización',
        () async {
      final service = UpdateService(
        cliente: _githubFalso(
          latest: _release('0.9.20'),
          lista: [_release('0.9.28'), _release('0.9.20')],
        ),
      );
      expect(await service.checkForUpdate(versionInstalada: '0.9.28'), isNull);
    });
  });

  group('fallos de red', () {
    test('un 404 en todo (repo sin releases) devuelve null', () async {
      final service = UpdateService(
        cliente: _githubFalso(latest: null, lista: null),
      );
      expect(await service.checkForUpdate(versionInstalada: '0.9.28'), isNull);
    });

    test('una excepción de red devuelve null en vez de reventar', () async {
      final service = UpdateService(
        cliente: MockClient((_) async => throw const SocketExceptionFalsa()),
      );
      expect(await service.checkForUpdate(versionInstalada: '0.9.28'), isNull);
    });
  });

  group('asset correcto por plataforma', () {
    // Un release con TODOS los binarios, como el que arma el espejo.
    final assets = [
      {'name': 'app-arm64-v8a-release.apk', 'size': 1},
      {'name': 'app-armeabi-v7a-release.apk', 'size': 1},
      {'name': 'app-x86_64-release.apk', 'size': 1},
      {'name': 'Bitly-Setup-0.9.29.exe', 'size': 1},
      {'name': 'Bitly-Setup-0.9.29-arm64.exe', 'size': 1},
      {'name': 'Bitly-0.9.29-macos.dmg', 'size': 1},
      {'name': 'Bitly-0.9.29-ios.ipa', 'size': 1},
    ];

    String? nombrePara(String plataforma, String arquitectura) {
      final asset = UpdateService.elegirAsset(
        assets,
        '0.9.29',
        plataforma: plataforma,
        arquitectura: arquitectura,
      );
      return asset?['name'] as String?;
    }

    test('Android elige el APK de su ABI', () {
      expect(nombrePara('android', 'arm64'), 'app-arm64-v8a-release.apk');
      expect(nombrePara('android', 'armv7'), 'app-armeabi-v7a-release.apk');
      expect(nombrePara('android', 'x86_64'), 'app-x86_64-release.apk');
    });

    test('Windows elige el instalador (x64 y ARM64)', () {
      expect(nombrePara('windows', 'x64'), 'Bitly-Setup-0.9.29.exe');
      expect(nombrePara('windows', 'arm64'), 'Bitly-Setup-0.9.29-arm64.exe');
    });

    test('macOS elige el DMG (antes no encontraba nada: buscaba APKs)', () {
      expect(nombrePara('macos', 'arm64'), 'Bitly-0.9.29-macos.dmg');
    });

    test('iOS y Linux no ofrecen descarga in-app', () {
      // A un iPhone no se le puede ofrecer un APK; a un escritorio Linux,
      // tampoco (el proyecto no publica binario para Linux).
      expect(nombrePara('ios', 'arm64'), isNull);
      expect(nombrePara('linux', 'x64'), isNull);
      expect(UpdateService.patronesAsset('0.9.29', plataforma: 'ios'), isEmpty);
      expect(UpdateService.patronesAsset('0.9.29', plataforma: 'linux'), isEmpty);
    });

    test('un release sin el binario de esta plataforma no se ofrece', () {
      final soloMac = [
        {'name': 'Bitly-0.9.29-macos.dmg', 'size': 1},
      ];
      expect(
        UpdateService.elegirAsset(
          soloMac,
          '0.9.29',
          plataforma: 'android',
          arquitectura: 'arm64',
        ),
        isNull,
      );
    });
  });

  test('elegirReleaseMasNueva ignora los que no tienen asset usable', () {
    final elegido = UpdateService.elegirReleaseMasNueva(
      [
        _release('0.9.30', assets: const []),
        _release('0.9.29'),
        _release('0.9.28'),
      ],
      '0.9.28',
    );
    expect(elegido?['tag_name'], 'v0.9.29');
  });
}

/// Excepción propia para simular un fallo de red sin depender de dart:io (así
/// la prueba corre igual en la VM y en la web).
class SocketExceptionFalsa implements Exception {
  const SocketExceptionFalsa();
  @override
  String toString() => 'fallo de red simulado';
}
