// ─────────────────────────────────────────────────────────────
// verificacion_keepalive.dart — PART de servicio_verificacion.dart:
// keepalive silencioso de sesiones firmadas (Cloudflare). Las
// sesiones del gateway zarz son de vida corta (~1-2 min TTL), así
// que mientras la app está en primer plano un pase en segundo plano
// refresca cada sesión vigente antes de que expire — sin modal, sin
// challenge URL, sin bootstrap. El lado Go pacea cada fuente
// (intervalo mínimo + backoff) y solo refresca sesiones cuya
// expiración está dentro del lead del keepalive.
// Se conecta con: servicio_verificacion.dart (misma library).
// Parte del flujo: verificación de sesiones (keepalive en 2º plano).
// ─────────────────────────────────────────────────────────────

part of 'servicio_verificacion.dart';

/// Intervalo del pase silencioso de refresh de sesiones.
const _intervaloKeepalive = Duration(seconds: 25);

/// Keepalive silencioso. Mixin aplicado en ServicioVerificacion.
mixin VerificacionKeepalive on VerificacionEstado {
  Timer? _timerKeepalive;
  bool _keepaliveCorriendo = false;
  bool _appEnUso = false;
  bool _keepaliveAlgunaVezExitoso = false;

  void _iniciarTimerKeepalive() {
    _timerKeepalive ??= Timer.periodic(_intervaloKeepalive, (_) {
      unawaited(_keepaliveTick());
    });
  }

  void _detenerTimerKeepalive() {
    _timerKeepalive?.cancel();
    _timerKeepalive = null;
  }

  /// Un pase silencioso de keepalive: pedirle al backend refrescar cada sesión
  /// vigente cercana a expirar. Nunca muestra UI, nunca bootstrapea, y se
  /// omite mientras un dialog de captcha está abierto para que el flujo modal
  /// sea dueño del registro de sesión durante un intercambio.
  Future<void> _keepaliveTick() async {
    if (!_appEnUso || _keepaliveCorriendo || _dialogoAbierto || _pendiente != null) {
      return;
    }
    _keepaliveCorriendo = true;
    try {
      final backend = di.sl<BackendService>();
      final resultados = await backend
          .keepAliveSignedSessions()
          .timeout(const Duration(seconds: 8));
      final refrescadas = <String>[];
      resultados.forEach((fuente, estado) {
        if (estado is Map && estado['refreshed'] == true) {
          refrescadas.add(fuente);
        }
      });
      if (refrescadas.isNotEmpty) {
        _logVerificacion.i('[Verificacion] keepalive refrescó: $refrescadas');
      }
      _keepaliveAlgunaVezExitoso = true;
    } catch (e) {
      // Mantener silencio hasta el primer éxito: en arranque en frío el timer
      // puede dispararse antes de que el backend Go esté inicializado y de otro
      // modo spamearía un warning cada 25s detrás del gate de arranque.
      if (_keepaliveAlgunaVezExitoso) {
        _logVerificacion.w('[Verificacion] keepalive falló (reintentará): $e');
      }
    } finally {
      _keepaliveCorriendo = false;
    }
  }

  /// Maneja los cambios de lifecycle para el keepalive: refrescar sesiones solo
  /// mientras la app está en uso (foreground/resumed). Pausar o backgroundear
  /// detiene el timer para nunca refrescar en segundo plano — las sesiones
  /// vencidas se re-challengen con una acción explícita del usuario al volver.
  void _onLifecycle(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      if (!_appEnUso) {
        _appEnUso = true;
        _iniciarTimerKeepalive();
      }
    } else {
      if (_appEnUso) {
        _appEnUso = false;
        _detenerTimerKeepalive();
      }
    }
  }
}