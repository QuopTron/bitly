// ─────────────────────────────────────────────────────────────
// servicio_callback_oauth.dart — Espera el callback OAuth (PKCE)
// de una extensión: el proveedor abre la página de authorize en el
// navegador del sistema con redirect a `spotiflac://callback`,
// Android captura el deep link y lo reenvía por el MethodChannel
// 'com.bitly/oauth_callback', y este servicio completa el waiter
// pendiente. Verifica el state (CSRF), maneja timeout y da un
// período de gracia al volver de segundo plano.
// Se conecta con: plataforma (deep link nativo) + resultado_oauth.dart.
// Parte del flujo: autenticación de extensiones (PKCE).
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'resultado_oauth.dart';

final _log = Logger();

/// Servicio singleton que espera callbacks OAuth por deep link.
class ServicioCallbackOAuth with WidgetsBindingObserver {
  static final ServicioCallbackOAuth _instancia = ServicioCallbackOAuth._();
  factory ServicioCallbackOAuth() => _instancia;
  ServicioCallbackOAuth._();

  static const _canal = MethodChannel('com.bitly/oauth_callback');
  static const _graciaReanudar = Duration(seconds: 2);

  Completer<ResultadoOAuth?>? _pendiente;
  Timer? _timeout;
  bool _inicializado = false;

  /// Registra el listener del canal nativo. Llamar una vez al arranque
  /// (app.dart) antes de cualquier waitForCallback. Idempotente.
  void init() {
    if (_inicializado) return;
    _inicializado = true;
    _canal.setMethodCallHandler((call) async {
      if (call.method == 'onOAuthCallback') {
        _log.i('[ServicioCallbackOAuth] callback OAuth recibido');
        final args = call.arguments;
        if (args is Map) {
          _completar(ResultadoOAuth(
            code: (args['code'] as String? ?? '').trim(),
            state: (args['state'] as String? ?? '').trim(),
            error: (args['error'] as String? ?? '').trim(),
          ));
        } else {
          _completar(null);
        }
      }
      return null;
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El usuario volvió del navegador. Si el deep link no llegó aún, dar un
    // margen corto; si no, fallar rápido en vez de esperar el timeout completo.
    if (state != AppLifecycleState.resumed) return;
    final pendiente = _pendiente;
    if (pendiente == null) return;
    Timer(_graciaReanudar, () {
      if (identical(pendiente, _pendiente)) _completar(null);
    });
  }

  /// Espera un callback OAuth.
  ///
  /// [stateEsperado] (el `state` PKCE) se valida cuando se provee; un
  /// desajuste resuelve null. Devuelve null en cancelación, timeout,
  /// rechazo o desajuste de state — el llamador debe tratarlo como fallo.
  Future<ResultadoOAuth?> esperarCallback({
    String? stateEsperado,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    _completar(null); // cancela cualquier waiter previo pendiente
    final completer = Completer<ResultadoOAuth?>();
    _pendiente = completer;
    _timeout = Timer(timeout, () {
      _log.w('[ServicioCallbackOAuth] callback OAuth agotó '
          '${timeout.inMinutes} min');
      _completar(null);
    });

    final result = await completer.future;
    if (result == null) return null;
    if (result.esError) {
      _log.w('[ServicioCallbackOAuth] error OAuth: ${result.error}');
      return null;
    }
    if (!result.coincideConState(stateEsperado)) {
      _log.w('[ServicioCallbackOAuth] state no coincide '
          '(esperado $stateEsperado, recibido ${result.state})');
      return null;
    }
    return result;
  }

  void _completar(ResultadoOAuth? result) {
    final c = _pendiente;
    _pendiente = null;
    _timeout?.cancel();
    _timeout = null;
    if (c != null && !c.isCompleted) c.complete(result);
  }
}