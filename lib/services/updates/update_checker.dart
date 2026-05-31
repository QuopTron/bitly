/// Comprobador de actualizaciones via GitHub Releases API.
/// Soporta canales stable y preview, selecciona el APK adecuado
/// usando el backend de Go para todas las llamadas HTTP.
library;

export 'package:bitly/services/updates/update_models.dart';

import 'dart:io';

import 'package:bitly/constants/app_info.dart';
import 'package:bitly/services/updates/update_models.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('UpdateChecker');

class UpdateChecker {
  /// Verifica si hay una actualización disponible en GitHub
  /// 
  /// Usa el backend de Go para hacer las llamadas HTTP a la API de GitHub.
  /// [channel] puede ser 'stable' (default) o 'preview'
  /// [repo] es opcional y por default usa AppInfo.githubRepo
  /// Devuelve null si no hay actualización o ocurre un error
  static Future<UpdateInfo?> checkForUpdate({String channel = 'stable'}) async {
    if (!Platform.isAndroid) return null;

    try {
      _log.i('Checking for updates via Go backend (channel: $channel)');
      
      final result = await PlatformBridge.checkGitHubUpdate(
        channel: channel,
        repo: AppInfo.githubRepo,
      );

      // Manejar error
      if (result['error'] != null) {
        final error = result['error'] as String? ?? 'Unknown error';
        _log.w('Update check error: $error');
        return null;
      }

      // Parsear el resultado
      final hasUpdate = result['has_update'] as bool? ?? false;
      if (!hasUpdate) {
        final version = result['version'] as String? ?? 'unknown';
        _log.i('No update available (current: ${AppInfo.version}, latest: $version, channel: $channel)');
        return null;
      }

      // Obtener los datos de la release
      final version = result['version'] as String? ?? '';
      final changelog = result['changelog'] as String? ?? 'No changelog available';
      final downloadUrl = result['download_url'] as String? ?? '${AppInfo.githubUrl}/releases';
      final apkDownloadUrl = result['apk_download_url'] as String?;
      final isPrerelease = result['is_prerelease'] as bool? ?? false;
      
      // Parsear published_at (puede estar en ISO 8601 string o timestamp)
      DateTime publishedAt;
      final publishedAtValue = result['published_at'];
      if (publishedAtValue is String) {
        publishedAt = DateTime.tryParse(publishedAtValue) ?? DateTime.now();
      } else {
        publishedAt = DateTime.now();
      }

      _log.i('Update available: $version (prerelease: $isPrerelease), APK: ${apkDownloadUrl != null ? 'available' : 'none'}');

      return UpdateInfo(
        version: version,
        changelog: changelog,
        downloadUrl: downloadUrl,
        apkDownloadUrl: apkDownloadUrl,
        publishedAt: publishedAt,
        isPrerelease: isPrerelease,
      );
    } catch (e) {
      _log.e('Error checking for updates via Go backend: $e');
      return null;
    }
  }

  static String get currentVersion => AppInfo.version;
}
