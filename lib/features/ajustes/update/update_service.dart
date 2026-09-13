// ─────────────────────────────────────────────────────────────
// update_service.dart — Detector de versiones multiplataforma.
// Consulta el último GitHub Release, detecta la plataforma y la
// ARQUITECTURA del dispositivo y elige el asset correcto:
//   · Android: app-arm64-v8a-release.apk / app-armeabi-v7a-release.apk
//              / app-x86_64-release.apk
//   · Windows: Bitly-Setup-x.x.x.exe (o Bitly-x.x.x-x64.exe)
// Los nombres deben ser consistentes porque el sitio web del
// proyecto lee los mismos assets del release para ofrecer la
// descarga correcta a cada visitante.
// Se conecta con: api.github.com (releases) + update_modal.
// Parte del flujo: Ajustes → Versión → actualización.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'update_info.dart';

/// Detecta versión/arquitectura y resuelve el asset del release.
class UpdateService {
  static const releaseUrl =
      'https://api.github.com/repos/QuopTron/bitly/releases/latest';

  static const _cabeceras = {'Accept': 'application/vnd.github.v3+json'};

  /// Plataforma actual: `android` | `windows` | `linux` | `macos`.
  static String get plataforma {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    return 'android';
  }

  /// Arquitectura actual: `arm64` | `armv7` | `x86_64` | `x64` | `x86`.
  static String get arquitectura {
    if (Platform.isAndroid) return _abiAndroid();
    if (Platform.isWindows || Platform.isLinux) return _archEscritorio();
    if (Platform.isMacOS) return _archMac();
    return 'arm64';
  }

  /// ABI del celular (`ro.product.cpu.abi`) normalizada.
  static String _abiAndroid() {
    try {
      final r = Process.runSync('getprop', ['ro.product.cpu.abi']);
      final abi = r.stdout.toString().trim().toLowerCase();
      if (abi.contains('arm64') || abi.contains('aarch64')) return 'arm64';
      if (abi.contains('armeabi-v7a') || abi.contains('armv7')) return 'armv7';
      if (abi.contains('x86_64') || abi.contains('amd64')) return 'x86_64';
      if (abi.contains('x86')) return 'x86_64';
    } catch (_) {}
    return 'arm64';
  }

  /// Arquitectura en Windows/Linux vía las variables de entorno del
  /// procesador (`AMD64` → x64, `ARM64` → arm64).
  static String _archEscritorio() {
    final env = Platform.environment;
    final valor =
        '${env['PROCESSOR_ARCHITECTURE'] ?? ''} '
        '${env['PROCESSOR_ARCHITEW6432'] ?? ''}'
            .toUpperCase();
    if (valor.contains('ARM64') || valor.contains('AARCH64')) return 'arm64';
    if (valor.contains('AMD64') ||
        valor.contains('X64') ||
        valor.contains('X86_64')) {
      return 'x64';
    }
    if (valor.contains('X86')) return 'x86';
    return 'x64';
  }

  static String _archMac() {
    try {
      final r = Process.runSync('uname', ['-m']);
      final m = r.stdout.toString().trim().toLowerCase();
      if (m.contains('arm64') || m.contains('aarch64')) return 'arm64';
    } catch (_) {}
    return 'x86_64';
  }

  /// Nombres de asset esperados (en orden de preferencia) para [version].
  /// El sitio web del proyecto usa los MISMOS nombres, así que deben
  /// coincidir exactamente con lo que publica el workflow de release.
  static List<String> patronesAsset(String version) {
    if (plataforma == 'windows') {
      final esArm = arquitectura.contains('arm');
      if (esArm) {
        return [
          'Bitly-Setup-$version-arm64.exe',
          'Bitly-$version-arm64.exe',
          'Bitly-Setup-$version.exe',
        ];
      }
      return [
        'Bitly-Setup-$version.exe',
        'Bitly-Setup-$version-x64.exe',
        'Bitly-$version-x64.exe',
        'Bitly-Setup-x64.exe',
      ];
    }
    switch (arquitectura) {
      case 'armv7':
        return ['app-armeabi-v7a-release.apk'];
      case 'x86_64':
        return ['app-x86_64-release.apk'];
      case 'arm64':
      default:
        return ['app-arm64-v8a-release.apk'];
    }
  }

  /// Elige el asset del release que corresponde a esta plataforma y
  /// arquitectura. Devuelve el mapa del asset de GitHub, o null si no hay
  /// ninguno descargable para este dispositivo.
  static Map<String, dynamic>? elegirAsset(
    List<dynamic> assets,
    String version,
  ) {
    if (assets.isEmpty) return null;

    for (final patron in patronesAsset(version)) {
      for (final a in assets) {
        if ((a['name'] as String? ?? '') == patron) {
          return Map<String, dynamic>.from(a as Map);
        }
      }
    }

    // Fallback por extensión + palabra clave de arquitectura.
    final ext = plataforma == 'windows' ? '.exe' : '.apk';
    final claves = plataforma == 'windows'
        ? [arquitectura.contains('arm') ? 'arm64' : 'x64']
        : <String>[];
    for (final a in assets) {
      final n = ((a['name'] as String?) ?? '').toLowerCase();
      if (!n.endsWith(ext)) continue;
      if (claves.isEmpty || claves.any(n.contains)) {
        return Map<String, dynamic>.from(a as Map);
      }
    }
    // Último recurso: cualquier asset con la extensión de la plataforma.
    for (final a in assets) {
      final n = ((a['name'] as String?) ?? '').toLowerCase();
      if (n.endsWith(ext)) return Map<String, dynamic>.from(a as Map);
    }
    return null;
  }

  /// Atajo: URL directa de descarga del asset correcto para [version].
  static String? urlDescarga(List<dynamic> assets, String version) {
    final asset = elegirAsset(assets, version);
    final url = asset?['browser_download_url'] as String?;
    return (url == null || url.isEmpty) ? null : url;
  }

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
      final asset = elegirAsset(assets, latestVersion);
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
    final largo = nuevas.length > actuales.length
        ? nuevas.length
        : actuales.length;
    for (var i = 0; i < largo; i++) {
      final n = i < nuevas.length ? nuevas[i]! : 0;
      final c = i < actuales.length ? actuales[i]! : 0;
      if (n > c) return true;
      if (n < c) return false;
    }
    return false;
  }
}
