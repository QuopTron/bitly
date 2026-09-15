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

import 'package:flutter/foundation.dart';

import '../verificacion/grant_verificacion.dart';

part 'servidor_callback_escritorio_helpers.dart';

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
      } catch (e) { debugPrint("[OAuth] error: $e"); }
    }

    _debugLog('grant extraído: ${grant == null ? 'null' : 'OK (${grant.length} chars)'}');

    if (grant != null && grant.isNotEmpty) {
      // Responder antes de completar para que la pestaña cierre limpio.
      request.response
        ..headers.contentType = ContentType.html
        ..write(_paginaExito);
      unawaited(request.response.close());
      // ignore: avoid_print
      debugPrint('[Verificacion] loopback recibió grant');
      _completar(grant);
      return;
    }

    // ignore: avoid_print
    debugPrint('[Verificacion] loopback recibió petición sin grant: $urlCompleta');
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('missing grant');
    await request.response.close();
  }

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
