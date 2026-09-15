// ─────────────────────────────────────────────────────────────
// settings_sheet_version_download.dart — PART de settings_sheet_new.dart: descarga del instalador de una
// nueva versión desde la hoja de releases.
// Se conecta con: settings_sheet_new.dart (misma library) + update_service.
// Parte del flujo: Ajustes → Más (descargar versión).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Descarga un APK de release a archivos temporales y lo abre para instalar.
void _downloadApk(String url, String version) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/bitly_v$version.apk');
    final resp = await http.get(Uri.parse(url));
    await file.writeAsBytes(resp.bodyBytes);
    await OpenFilex.open(file.path);
  } catch (e) { debugPrint("[Feature] $e"); }
}

/// Limpia el markdown del changelog para mostrarlo como texto plano.
String _stripChangelog(String body) {
  return body
      .replaceAll(RegExp(r'#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'\*+'), '')
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'\1')
      .replaceAll(RegExp(r'`'), '')
      .trim();
}
