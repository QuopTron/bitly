// ─────────────────────────────────────────────────────────────
// update_assets.dart — Detección de plataforma y arquitectura del
// dispositivo y elección del asset correcto del release de GitHub.
// Los nombres de asset deben coincidir con los que publica el
// workflow de release (el sitio web usa los mismos).
// Se conecta con: update_service.dart (lo usa).
// Parte del flujo: Ajustes → Versión → actualización.
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/foundation.dart';

/// Plataforma, arquitectura y assets esperados de un release.
class UpdateAssets {
  UpdateAssets._();

  /// Plataforma actual: `android` | `ios` | `windows` | `linux` | `macos`.
  ///
  /// `ios` y `linux` existen (y no caen en `android`) porque NO hay binario
  /// que instalar desde acá: en iOS las actualizaciones van por TestFlight/App
  /// Store (la IPA que publica el CI está sin firmar) y el proyecto no publica
  /// nada para Linux. Antes iOS caía en `android` y la app le ofrecía un APK a
  /// un iPhone; Linux, un APK a un escritorio.
  static String get plataforma {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
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
    } catch (e) {
      debugPrint("[Update] $e");
    }
    return 'arm64';
  }

  /// Arquitectura en Windows/Linux vía variables de entorno del procesador.
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
    } catch (e) {
      debugPrint("[Update] $e");
    }
    return 'x86_64';
  }

  /// Nombres de asset esperados (en orden de preferencia) para [version].
  ///
  /// [plataforma] y [arquitectura] se pueden forzar para probar las
  /// plataformas que no son la de la máquina que corre las pruebas; en la app
  /// salen del dispositivo.
  ///
  /// Devuelve una lista VACÍA cuando no hay nada que ofrecer (iOS y Linux):
  /// el detector lo trata como "no hay descarga para este aparato".
  static List<String> patronesAsset(
    String version, {
    String? plataforma,
    String? arquitectura,
  }) {
    final p = plataforma ?? UpdateAssets.plataforma;
    final a = arquitectura ?? UpdateAssets.arquitectura;

    // Sin binario instalable desde acá: ver la nota de [plataforma].
    if (p == 'ios' || p == 'linux') return const [];

    if (p == 'windows') {
      if (a.contains('arm')) {
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

    // macOS se publica como DMG (Bitly-X.Y.Z-macos.dmg, el nombre que arma el
    // workflow de Apple). Sin este caso, macOS buscaba APKs, no encontraba
    // nada y el aviso de versión nueva nunca aparecía en esa plataforma.
    if (p == 'macos') {
      return ['Bitly-$version-macos.dmg', 'Bitly-$version.dmg'];
    }

    switch (a) {
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
  /// arquitectura, o null si no hay ninguno descargable.
  static Map<String, dynamic>? elegirAsset(
    List<dynamic> assets,
    String version, {
    String? plataforma,
    String? arquitectura,
  }) {
    if (assets.isEmpty) return null;
    final p = plataforma ?? UpdateAssets.plataforma;
    final a = arquitectura ?? UpdateAssets.arquitectura;

    final esperados = patronesAsset(
      version,
      plataforma: p,
      arquitectura: a,
    );
    // Sin binario para esta plataforma (iOS, Linux): no hay nada que elegir.
    if (esperados.isEmpty) return null;

    for (final patron in esperados) {
      for (final asset in assets) {
        if ((asset['name'] as String? ?? '') == patron) {
          return Map<String, dynamic>.from(asset as Map);
        }
      }
    }

    // Fallback por extensión + palabra clave de arquitectura.
    final ext = p == 'windows'
        ? '.exe'
        : p == 'macos'
        ? '.dmg'
        : '.apk';
    final claves =
        p == 'windows' ? [a.contains('arm') ? 'arm64' : 'x64'] : <String>[];
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

  /// URL directa de descarga del asset correcto para [version].
  static String? urlDescarga(
    List<dynamic> assets,
    String version, {
    String? plataforma,
    String? arquitectura,
  }) {
    final asset = elegirAsset(
      assets,
      version,
      plataforma: plataforma,
      arquitectura: arquitectura,
    );
    final url = asset?['browser_download_url'] as String?;
    return (url == null || url.isEmpty) ? null : url;
  }
}
