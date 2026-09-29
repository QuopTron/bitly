// ─────────────────────────────────────────────────────────────
// settings_sheet_report_submit.dart — PART de settings_sheet_new.dart: envío del reporte al backend
// con manejo de errores y acuse al usuario.
// Se conecta con: settings_sheet_new.dart (misma library) + backend Go.
// Parte del flujo: Ajustes → Más (enviar reporte).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Crea un issue de GitHub en QuopTron/bitly con el token configurado.
/// Devuelve true cuando el issue se creó correctamente.
Future<bool> submitReport({
  required BuildContext context,
  required bool isBug,
  required String title,
  required String body,
}) async {
  if (title.isEmpty) return false;
  try {
    final pkg = await PackageInfo.fromPlatform();
    final appVersion = 'v${pkg.version}';
    final prefix = isBug ? '[Bug]' : '[Sugerencia]';
    final issueBody = [
      body,
      '',
      '---',
      'App: Bitly $appVersion',
      'Plataforma: ${Platform.isAndroid
          ? 'Android'
          : Platform.isIOS
          ? 'iOS'
          : Platform.isLinux
          ? 'Linux'
          : Platform.isWindows
          ? 'Windows'
          : Platform.isMacOS
          ? 'macOS'
          : 'desktop'}',
    ].join('\n');
    // El issue lo crea el WORKER, no la app: antes esta petición necesitaba el
    // token de GitHub compilado adentro (que se sacaba del APK con unzip).
    return sl<BackendService>().enviarReporte(
      titulo: '$prefix $title',
      cuerpo: issueBody,
    );
  } catch (e) {
    debugPrint('[settings_sheet_report_submit] $e');
    return false;
  }
}
