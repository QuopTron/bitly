// ─────────────────────────────────────────────────────────────
// verificacion_keepalive.dart — PART de servicio_verificacion.dart:
// keepalive silencioso de sesiones firmadas (Cloudflare). Las
// sesiones del gateway zarz son de vida corta (~1-2 min TTL), así
// que un pase silencioso refresca cada sesión vigente antes de que
// expire — sin modal, sin challenge URL, sin bootstrap. El lado Go
// pacea cada fuente (intervalo mínimo + backoff) y solo refresca
// sesiones cuya expiración está dentro del lead del keepalive.
//
// IMPORTANTE: con un TTL tan corto, dejar de refrescar = perder la
// sesión en menos de 2 minutos y volver a pedir un challenge humano.
// Por eso el timer NO se detiene al pasar a segundo plano: el proceso
// sigue vivo mientras suena audio (servicio en foreground) y ese
// refresh es justo lo que mantiene la sesión caliente. Solo se detiene
// cuando el proceso va a morir (detached).
// Se conecta con: servicio_verificacion.dart (misma library) +
// connectivity_plus (refresco inmediato al recuperar red).
// Parte del flujo: verificación de sesiones (keepalive en 2º plano).
// ─────────────────────────────────────────────────────────────

part of 'servicio_verificacion.dart';

/// Intervalo del pase silencioso de refresh de sesiones. Debe quedar por
/// debajo del TTL del gateway (~1-2 min) para alcanzar 2-3 refrescos por
/// vida de sesión; si se sube, la sesión puede morir entre pases.
const _intervaloKeepalive = Duration(seconds: 25);

/// Keepalive silencioso. Mixin aplicado en ServicioVerificacion.
mixin VerificacionKeepalive on VerificacionEstado {
  Timer? _timerKeepalive;
  bool _keepaliveCorriendo = false;
  bool _appEnUso = false;
  bool _keepaliveAlgunaVezExitoso = false;
  StreamSubscription<List<ConnectivityResult>>? _subRedKeepalive;

  /// Escucha cambios de conectividad: al recuperar red se fuerza un pase
  /// inmediato, porque el timer pudo perderse refrescos durante el corte y
  /// la sesión quizá esté a segundos de expirar.
  void _escucharRedParaKeepalive() {
    if (_subRedKeepalive != null) return;
    try {
      _subRedKeepalive = Connectivity().onConnectivityChanged.listen((res) {
        final hayRed = res.any((r) => r != ConnectivityResult.none);
        if (hayRed) unawaited(_keepaliveTick());
      });
    } catch (_) {
      // Sin plugin de conectividad el timer sigue bastando.
    }
  }

  void _dejarDeEscucharRed() {
    _subRedKeepalive?.cancel();
    _subRedKeepalive = null;
  }

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

  /// Maneja los cambios de lifecycle para el keepalive.
  ///
  /// El timer sigue corriendo en segundo plano a propósito: las sesiones
  /// viven ~1-2 min y el proceso permanece vivo mientras suena audio, así que
  /// refrescar en background es lo que evita el Turnstile al volver. Solo se
  /// apaga cuando el proceso se desmonta (detached). Al volver al primer
  /// plano se dispara un pase inmediato para recuperar la sesión antes de
  /// cualquier acción del usuario.
  void _onLifecycle(AppLifecycleState estado) {
    if (estado == AppLifecycleState.detached) {
      _appEnUso = false;
      _detenerTimerKeepalive();
      _dejarDeEscucharRed();
      return;
    }
    if (estado == AppLifecycleState.resumed) {
      _appEnUso = true;
      _iniciarTimerKeepalive();
      _escucharRedParaKeepalive();
      unawaited(_keepaliveTick());
      return;
    }
    // paused / inactive / hidden: mantener el refresh silencioso.
    _appEnUso = true;
    _iniciarTimerKeepalive();
  }
}