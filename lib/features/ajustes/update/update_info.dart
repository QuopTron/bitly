// ─────────────────────────────────────────────────────────────
// update_info.dart — Modelo de la actualización disponible: versión
// del release de GitHub, notas, URL del asset que corresponde a la
// plataforma/arquitectura del dispositivo y su tamaño.
// Se conecta con: update_service.dart (lo construye) +
// update_modal.dart (lo muestra) + settings_sheet_version_*.
// Parte del flujo: Ajustes → Versión → actualización.
// ─────────────────────────────────────────────────────────────

/// Datos de una actualización disponible publicada como GitHub Release.
class UpdateInfo {
  /// Versión del release sin la `v` inicial (p.ej. `0.9.10`).
  final String version;

  /// Notas del release (markdown tal cual lo publica GitHub).
  final String body;

  /// URL directa de descarga del asset correcto para este dispositivo
  /// (`.apk` en Android, `.exe` en Windows).
  final String downloadUrl;

  /// Tamaño del asset en bytes (para mostrarlo en el modal).
  final int? apkSize;

  /// Nombre del asset elegido (p.ej. `app-arm64-v8a-release.apk`).
  final String? nombreAsset;

  const UpdateInfo({
    required this.version,
    required this.body,
    required this.downloadUrl,
    this.apkSize,
    this.nombreAsset,
  });
}
