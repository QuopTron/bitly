// ─────────────────────────────────────────────────────────────
// servidor_callback_escritorio.dart — Servidor HTTP loopback local
// usado en escritorio (Windows/Linux) para recibir el grant de
// sesión firmada de Cloudflare. webview_flutter no tiene
// implementación para Windows/Linux, así que el challenge apunta
// su callback a http://127.0.0.1:<port>/session-grant y el grant
// vuelve por esta URL (navegación del WebView o fetch de la página).
// Se conecta con: backend_go (setSignedSessionCallbackUrl) y la
// verificación de sesiones firmadas.
// Parte del flujo: verificación de sesiones (Cloudflare) en desktop.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'grant_verificacion.dart';

/// Servidor loopback para recibir el grant de sesión firmada.
class ServidorCallbackEscritorio {
  ServidorCallbackEscritorio._();

  static final ServidorCallbackEscritorio instance = ServidorCallbackEscritorio._();

  HttpServer? _servidor;
  Completer<String?>? _pendiente;
  Timer? _timeout;

  int? get puerto => _servidor?.port;

  bool get estaListo => _servidor != null;

  /// Vincula el servidor loopback en un puerto libre (idempotente).
  Future<bool> garantizarIniciado() async {
    if (_servidor != null) return true;
    try {
      _servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _servidor!.listen(_manejar);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _manejar(HttpRequest request) async {
    final urlCompleta = request.uri.toString();
    _debugLog('petición: ${request.method} $urlCompleta');

    // El grant puede llegar en la query (navegación) o en el CUERPO (POST de
    // la página). Se parsea con el MISMO helper tolerante que usa el WebView
    // in-app (grantDeCadena): tolera las tres formas reales del contrato de
    // zarz — URL completa, URL con la query malformada (`?cb_version=v2grant?grant=gr_...`)
    // y token pelado. Antes se leía solo `queryParameters['grant']` de forma
    // estricta y el caso malformado (el que usa zarz) se descartaba en
    // silencio → en Windows el modal abría, el usuario verificaba y quedaba
    // abierto para siempre (en Android no pasaba porque ahí usa el parser
    // tolerante del deep link).
    var grant = grantDeCadena(urlCompleta);

    if (grant == null) {
      try {
        final cuerpo = await utf8.decoder.bind(request).join();
        grant = _extraerDelCuerpo(cuerpo);
      } catch (_) {}
    }

    _debugLog('grant extraído: ${grant == null ? 'null' : 'OK (${grant.length} chars)'}');

    if (grant != null && grant.isNotEmpty) {
      // Responder antes de completar para que la pestaña cierre limpio.
      request.response
        ..headers.contentType = ContentType.html
        ..write(_paginaExito);
      unawaited(request.response.close());
      // ignore: avoid_print
      print('[Verificacion] loopback recibió grant');
      _completar(grant);
      return;
    }

    // ignore: avoid_print
    print('[Verificacion] loopback recibió petición sin grant: $urlCompleta');
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('missing grant');
    await request.response.close();
  }

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
    } catch (_) {}
    // 2) Form-encoded / query.
    try {
      final params = Uri.splitQueryString(t);
      for (final clave in ['grant', 'code', 'token']) {
        final valor = params[clave];
        if (valor != null && valor.trim().isNotEmpty) return valor.trim();
      }
    } catch (_) {}
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
    } catch (_) {}
  }

  static const _paginaExito = '''
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>Verificación completada</title></head>
<body style="font-family:sans-serif;background:#000;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh">
<div style="text-align:center">
<h2>✔ Verificación completada</h2>
<p>Ya puedes cerrar esta pestaña y volver a la app.</p>
</div></body></html>''';

  /// Espera el siguiente grant (o null si expira/lo cancelan).
  Future<String?> esperarGrant(Duration timeout) {
    _completar(null); // cancela cualquier espera vieja
    final completer = Completer<String?>();
    _pendiente = completer;
    _timeout = Timer(timeout, () => _completar(null));
    return completer.future;
  }

  /// Cancela cualquier espera pendiente (p.ej. el usuario saltó la verificación).
  void cancelar() {
    _completar(null);
  }

  void _completar(String? grant) {
    final c = _pendiente;
    _pendiente = null;
    _timeout?.cancel();
    _timeout = null;
    if (c != null && !c.isCompleted) c.complete(grant);
  }
}
