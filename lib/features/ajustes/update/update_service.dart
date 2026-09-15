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

/// Detecta versión/arquitectura y resuelve el asset del release.
class UpdateService {
  static const releaseUrl =
      'https://api.github.com/repos/QuopTron/bitly/releases/latest';

  static const _cabeceras = {'Accept': 'application/vnd.github.v3+json'};

  /// Plataforma actual (ver [UpdateAssets]).
  static String get plataforma => UpdateAssets.plataforma;

  /// Arquitectura actual (ver [UpdateAssets]).
  static String get arquitectura => UpdateAssets.arquitectura;

  /// Nombres de asset esperados para [version].
  static List<String> patronesAsset(String version) =>
      UpdateAssets.patronesAsset(version);

  /// Elige el asset del release para este dispositivo.
  static Map<String, dynamic>? elegirAsset(
    List<dynamic> assets,
    String version,
  ) =>
      UpdateAssets.elegirAsset(assets, version);

  /// URL directa de descarga del asset correcto para [version].
  static String? urlDescarga(List<dynamic> assets, String version) =>
      UpdateAssets.urlDescarga(assets, version);

  /// Consulta el último release y devuelve la actualización si es más
  /// nueva que la instalada (si no, null).
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response =
          await http.get(Uri.parse(releaseUrl), headers: _cabeceras);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      if (json is! Map) return null;

      final tag = json['tag_name'] as String? ?? '';
      final latestVersion = tag.replaceFirst('v', '').trim();
      if (latestVersion.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      if (esMasNueva(latestVersion, packageInfo.version) != true) return null;

      final assets = json['assets'] as List<dynamic>? ?? [];
      final asset = UpdateAssets.elegirAsset(assets, latestVersion);
      if (asset == null) return null;

      final url = asset['browser_download_url'] as String?;
      if (url == null || url.isEmpty) return null;

      return UpdateInfo(
        version: latestVersion,
        body: json['body'] as String? ?? '',
        downloadUrl: url,
        apkSize: asset['size'] as int?,
        nombreAsset: asset['name'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// ¿[nueva] es una versión semántica mayor que [actual]? Devuelve null si
  /// alguna no se puede parsear.
  static bool? esMasNueva(String nueva, String actual) {
    final nuevas = nueva.split('.').map(int.tryParse).toList();
    final actuales = actual.split('.').map(int.tryParse).toList();
    if (nuevas.any((p) => p == null) || actuales.any((p) => p == null)) {
      return null;
    }
    final largo =
        nuevas.length > actuales.length ? nuevas.length : actuales.length;
    for (var i = 0; i < largo; i++) {
      final n = i < nuevas.length ? nuevas[i]! : 0;
      final c = i < actuales.length ? actuales[i]! : 0;
      if (n > c) return true;
      if (n < c) return false;
    }
    return false;
  }
}
