/// Modelos de datos para el sistema de actualizaciones.
/// Define [UpdateInfo] con la información de la release y los tipos
/// internos [_ApkVariant] y [_ApkAsset] para la selección del APK
/// según la arquitectura del dispositivo.
library;

enum ApkVariant { arm64, arm32, universal }

class ApkAsset {
  final String name;
  final String url;
  final ApkVariant variant;

  const ApkAsset({
    required this.name,
    required this.url,
    required this.variant,
  });
}

class UpdateInfo {
  final String version;
  final String changelog;
  final String downloadUrl;
  final String? apkDownloadUrl;
  final DateTime publishedAt;
  final bool isPrerelease;

  const UpdateInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    this.apkDownloadUrl,
    required this.publishedAt,
    this.isPrerelease = false,
  });
}
