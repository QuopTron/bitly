// ─────────────────────────────────────────────────────────────
// servidor_callback_escritorio_helpers.dart — PART de
// servidor_callback_escritorio.dart: piezas del servidor loopback —
// página HTML de éxito que ve el usuario, parser tolerante del grant
// del cuerpo de la petición y log de diagnóstico a archivo (para
// poder ver en release qué recibe el loopback).
// Se conecta con: servidor_callback_escritorio.dart (misma library) +
// grant_verificacion.
// Parte del flujo: verificación de sesiones (Cloudflare) en desktop.
// ─────────────────────────────────────────────────────────────

part of 'servidor_callback_escritorio.dart';

/// Página que ve el usuario en la pestaña cuando el grant llegó bien.
const _paginaExito = '''
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>Verificación completada</title></head>
<body style="font-family:sans-serif;background:#000;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh">
<div style="text-align:center">
<h2>✔ Verificación completada</h2>
<p>Ya puedes cerrar esta pestaña y volver a la app.</p>
</div></body></html>''';

/// Extrae el grant del CUERPO de la petición (POST de la página). Acepta
/// JSON con clave explícita (incluso anidada en `data`), cuerpo
/// form-encoded/query (`grant=...&...`) y —solo como último recurso— un
/// token pelado con el prefijo real `gr_`. NO usa el fallback genérico de
/// `grantDeCadena` para no confundir un JSON arbitrario con un grant.
String? _extraerDelCuerpo(String cuerpo) {
  final t = cuerpo.trim();
  if (t.isEmpty) return null;
  // 1) JSON con clave explícita.
  try {
    final decodificado = jsonDecode(t);
    if (decodificado is Map) {
      for (final clave in ['grant', 'code', 'token', 'session_grant']) {
        final valor = decodificado[clave];
        if (valor is String && valor.trim().isNotEmpty) {
          return valor.trim();
        }
      }
      final data = decodificado['data'];
      if (data is Map) {
        for (final clave in ['grant', 'code', 'token']) {
          final valor = data[clave];
          if (valor is String && valor.trim().isNotEmpty) {
            return valor.trim();
          }
        }
      }
    }
  } catch (e) {
    debugPrint("[OAuth] error: $e");
  }
  // 2) Form-encoded / query.
  try {
    final params = Uri.splitQueryString(t);
    for (final clave in ['grant', 'code', 'token']) {
      final valor = params[clave];
      if (valor != null && valor.trim().isNotEmpty) return valor.trim();
    }
  } catch (e) {
    debugPrint("[OAuth] error: $e");
  }
  // 3) Token pelado con el prefijo real del grant.
  final m = RegExp(r'^gr_[A-Za-z0-9_\-]+$').firstMatch(t);
  return m?.group(0);
}

/// Log de diagnóstico a archivo (AppData/Bitly/verificacion_loopback.log)
/// para poder ver en release qué recibe el servidor loopback — en release
/// los print/debugPrint no son visibles.
void _debugLog(String mensaje) {
  try {
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        '';
    if (base.isEmpty) return;
    final dir = Directory('$base${Platform.pathSeparator}Bitly');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final archivo =
        File('${dir.path}${Platform.pathSeparator}verificacion_loopback.log');
    final linea = '[${DateTime.now().toIso8601String()}] $mensaje\n';
    archivo.writeAsStringSync(linea, mode: FileMode.append);
  } catch (e) {
    debugPrint("[OAuth] error: $e");
  }
}
