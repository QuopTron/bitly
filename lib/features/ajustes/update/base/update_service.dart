// ─────────────────────────────────────────────────────────────
// update_service.dart — Detector de versiones multiplataforma.
// Consulta el último GitHub Release, compara con la versión
// instalada y devuelve la info de actualización cuando hay una más
// nueva. La detección de plataforma/arquitectura y la elección del
// asset viven en update_assets.dart.
// Se conecta con: api.github.com (releases) + update_assets.
// Parte del flujo: Ajustes → Versión → actualización.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'update_assets.dart';
import 'update_info.dart';

import 'package:flutter/foundation.dart';
/// Detecta versión/arquitectura y resuelve el asset del release.
class UpdateService {
  /// [cliente] permite inyectar el cliente HTTP en las pruebas.
  UpdateService({http.Client? cliente}) : _cliente = cliente;

  final http.Client? _cliente;

  /// Cliente compartido cuando no se inyecta uno: el detector se consulta
  /// varias veces por sesión y así se reusan las conexiones (crear un cliente
  /// por consulta dejaba sockets abiertos sin cerrar).
  static final http.Client _clienteCompartido = http.Client();

  http.Client get _http => _cliente ?? _clienteCompartido;

  /// Repo PÚBLICO donde se espejan los binarios (ver release.yml,
  /// job `release-publico`).
  ///
  /// Por qué no el repo del código: es PRIVADO, y un asset de una release
  /// privada solo se baja con un token. Este chequeo es anónimo (no hay dónde
  /// esconder un token: vive en un APK que cualquiera abre), así que contra el
  /// repo privado la API responde 404 y el aviso de versión nueva nunca
  /// aparecía. El repo público no lleva código: solo Releases con los binarios
  /// ya compilados, que es lo único que este detector necesita leer.
  static const repoPublico = 'QuopTron/bitly-releases';

  static const releaseUrl =
      'https://api.github.com/repos/$repoPublico/releases/latest';

  /// Lista de releases: es el respaldo del detector (ver [checkForUpdate]).
  static const releasesUrl =
      'https://api.github.com/repos/$repoPublico/releases?per_page=30';

  /// Página pública de las releases (la usa la UI para "ver todas").
  static const releasesPagina =
      'https://github.com/$repoPublico/releases';

  static const _cabeceras = {'Accept': 'application/vnd.github.v3+json'};

  /// Plataforma actual (ver [UpdateAssets]).
  static String get plataforma => UpdateAssets.plataforma;

  /// Arquitectura actual (ver [UpdateAssets]).
  static String get arquitectura => UpdateAssets.arquitectura;

  /// Nombres de asset esperados para [version]. [plataforma]/[arquitectura]
  /// se pueden forzar en las pruebas.
  static List<String> patronesAsset(
    String version, {
    String? plataforma,
    String? arquitectura,
  }) => UpdateAssets.patronesAsset(
    version,
    plataforma: plataforma,
    arquitectura: arquitectura,
  );

  /// Elige el asset del release para este dispositivo.
  static Map<String, dynamic>? elegirAsset(
    List<dynamic> assets,
    String version, {
    String? plataforma,
    String? arquitectura,
  }) => UpdateAssets.elegirAsset(
    assets,
    version,
    plataforma: plataforma,
    arquitectura: arquitectura,
  );

  /// URL directa de descarga del asset correcto para [version].
  static String? urlDescarga(
    List<dynamic> assets,
    String version, {
    String? plataforma,
    String? arquitectura,
  }) => UpdateAssets.urlDescarga(
    assets,
    version,
    plataforma: plataforma,
    arquitectura: arquitectura,
  );

  /// Consulta el último release y devuelve la actualización si es más
  /// nueva que la instalada (si no, null).
  ///
  /// Cómo detecta (dos pasos, porque `/releases/latest` solo no alcanza):
  ///   1. `/releases/latest` — el camino normal y barato (una sola petición).
  ///   2. Si eso no dio una actualización, la LISTA de releases. Cubre las dos
  ///      formas en que `/latest` se queda corto:
  ///        · el espejo público creó una release VIEJA más tarde (un `gh
  ///          release upload` a mano o el cron de espejo), y "latest" pasa a
  ///          ser esa: sin el respaldo, la app diría "no hay nada nuevo";
  ///        · la última release no trae el binario de ESTA plataforma (por
  ///          ejemplo, un release donde falló el job de macOS), y la app se
  ///          quedaba sin ofrecer nada aunque existiera una versión completa.
  ///
  /// [versionInstalada] existe para las pruebas (en la app sale de
  /// `PackageInfo`).
  Future<UpdateInfo?> checkForUpdate({String? versionInstalada}) async {
    try {
      final instalada = versionInstalada ?? await _versionInstalada();
      if (instalada.isEmpty) return null;

      final ultimo = await _pedirJson(releaseUrl);
      if (ultimo is Map) {
        final info = _infoDeRelease(ultimo, instalada);
        if (info != null) return info;
      }

      final lista = await _pedirJson(releasesUrl);
      if (lista is List) {
        final release = elegirReleaseMasNueva(lista, instalada);
        if (release != null) return _infoDeRelease(release, instalada);
      }
      return null;
    } catch (e) {
      debugPrint('[UpdateService] $e');
      return null;
    }
  }

  /// Versión instalada según el paquete. `v0.9.28+16077` → `0.9.28`.
  static Future<String> _versionInstalada() async {
    final info = await PackageInfo.fromPlatform();
    return info.version.trim();
  }

  /// Petición a la API de GitHub; devuelve lo que venga (Map o List) o null.
  /// Cualquier fallo (sin red, 404, 403 por rate limit) es "no hay datos",
  /// nunca una excepción hacia la UI.
  Future<dynamic> _pedirJson(String url) async {
    try {
      final response = await _http.get(
        Uri.parse(url),
        headers: _cabeceras,
      );
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('[UpdateService] $url: $e');
      return null;
    }
  }

  /// Traduce un release de GitHub a [UpdateInfo] si es más nuevo que
  /// [instalada] y trae un asset para esta plataforma. Null en cualquier otro
  /// caso.
  UpdateInfo? _infoDeRelease(Map<dynamic, dynamic> release, String instalada) {
    if (release['draft'] == true || release['prerelease'] == true) return null;

    final tag = release['tag_name'] as String? ?? '';
    final version = tag.replaceFirst('v', '').trim();
    if (version.isEmpty) return null;
    if (esMasNueva(version, instalada) != true) return null;

    final assets = release['assets'] as List<dynamic>? ?? const [];
    final asset = UpdateAssets.elegirAsset(assets, version);
    if (asset == null) return null;

    final url = asset['browser_download_url'] as String?;
    if (url == null || url.isEmpty) return null;

    return UpdateInfo(
      version: version,
      body: release['body'] as String? ?? '',
      downloadUrl: url,
      apkSize: asset['size'] as int?,
      nombreAsset: asset['name'] as String?,
    );
  }

  /// Elige, entre [releases], la versión MÁS ALTA que sea más nueva que
  /// [instalada] y que tenga un asset descargable para esta plataforma.
  ///
  /// Existe porque `/releases/latest` es "el release creado más recientemente",
  /// no "el de versión más alta": si el espejo público sube una release vieja
  /// después que la nueva, `latest` apunta hacia atrás.
  static Map<String, dynamic>? elegirReleaseMasNueva(
    List<dynamic> releases,
    String instalada,
  ) {
    Map<String, dynamic>? mejor;
    String? mejorVersion;

    for (final r in releases) {
      if (r is! Map) continue;
      if (r['draft'] == true || r['prerelease'] == true) continue;

      final tag = r['tag_name'] as String? ?? '';
      final version = tag.replaceFirst('v', '').trim();
      if (version.isEmpty) continue;
      if (compararVersiones(version, instalada) != 1) continue;
      if (mejorVersion != null &&
          compararVersiones(version, mejorVersion) != 1) {
        continue;
      }

      final assets = (r['assets'] as List<dynamic>?) ?? const [];
      if (UpdateAssets.elegirAsset(assets, version) == null) continue;

      mejor = Map<String, dynamic>.from(r);
      mejorVersion = version;
    }
    return mejor;
  }

  /// ¿[nueva] es una versión semántica mayor que [actual]? Devuelve null si
  /// alguna no se puede parsear.
  static bool? esMasNueva(String nueva, String actual) {
    final comparacion = compararVersiones(nueva, actual);
    return comparacion == null ? null : comparacion > 0;
  }

  /// Compara dos versiones semánticas: 1 si [a] > [b], -1 si [a] < [b], 0 si
  /// son iguales y null si alguna no se puede parsear. Los tramos que faltan
  /// cuentan como 0, así `0.9` y `0.9.0` son la misma versión.
  static int? compararVersiones(String a, String b) {
    final partesA = a.split('.').map(int.tryParse).toList();
    final partesB = b.split('.').map(int.tryParse).toList();
    if (partesA.any((p) => p == null) || partesB.any((p) => p == null)) {
      return null;
    }
    final largo = partesA.length > partesB.length
        ? partesA.length
        : partesB.length;
    for (var i = 0; i < largo; i++) {
      final x = i < partesA.length ? partesA[i]! : 0;
      final y = i < partesB.length ? partesB[i]! : 0;
      if (x != y) return x > y ? 1 : -1;
    }
    return 0;
  }
}
