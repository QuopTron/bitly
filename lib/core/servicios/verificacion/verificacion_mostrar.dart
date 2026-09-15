// ─────────────────────────────────────────────────────────────
// verificacion_mostrar.dart — PART de servicio_verificacion.dart:
// orquesta la obtención del grant del challenge de Cloudflare:
// kill-switch, caso Linux (navegador + loopback), intento
// silencioso y, como último recurso, el dialog WebView visible
// (verificacion_dialogo.dart).
// Se conecta con: servicio_verificacion.dart (misma library).
// Parte del flujo: verificación de sesiones (mostrar challenge).
// ─────────────────────────────────────────────────────────────

part of 'servicio_verificacion.dart';

/// Muestra el challenge de Cloudflare. Mixin aplicado en ServicioVerificacion.
mixin VerificacionMostrar
    on VerificacionSilenciosa, VerificacionNavegador, VerificacionDialogo {
  /// Muestra el challenge en un dialog WebView in-app y devuelve el grant
  /// code, o null si se canceló/timeout.
  ///
  /// [intentarAuto] (default true): intenta primero el auto-pase de Turnstile
  /// en un WebView oculto (3×12s). El setup de bienvenida pasa false para
  /// abrir el WebView VISIBLE de inmediato — el usuario espera ver el sandbox
  /// al tocar Verificar, no 36s de "cargando" sin nada en pantalla.
  Future<String?> mostrarVerificacion({
    required String extId,
    required String nombreMostrado,
    required String urlAuth,
    Duration? timeout,
    bool intentarAuto = true,
  }) async {
    // Kill-switch absoluto: sin fuentes con sesión firmada, NINGÚN flujo puede
    // abrir el WebView de Cloudflare. Esto cubre cualquier caller nuevo que
    // pueda olvidar el check de fuentesSesionFirmada.
    debugPrint('[Verificacion] mostrarVerificacion called: extId=$extId fuentes=${ServicioVerificacion.fuentesSesionFirmada}');
    if (ServicioVerificacion.fuentesSesionFirmada.isEmpty) {
      debugPrint('[Verificacion] Kill-switch: fuentesSesionFirmada empty → returning null');
      return null;
    }
    // Solo honrar un skip mientras un run de provisionSignedSessions está
    // activo; los llamadores directos (slide de setup) siempre tienen su modal.
    if (_deshabilitado && _runActivo) return null;
    _completarPendiente(''); // cancelar cualquier completer pendiente stale
    final completador = Completer<String?>();
    _pendiente = completador;

    // Linux: webview_win_floating 2.x no soporta Linux (solo Windows), así abrir
    // el challenge en el navegador del sistema y recibir el grant en el servidor
    // loopback local (el backend apuntó el callback del challenge ahí). Si el
    // servidor callback no pudo bindear, skip de la fuente en vez de mostrar un
    // dialog WebView roto.
    if (Platform.isLinux) {
      final callbackDesktop = ServidorCallbackEscritorio.instance;
      if (!callbackDesktop.estaListo) {
        _logVerificacion.w('[Verificacion] Servidor callback desktop no '
            'disponible, omitiendo verificación de $extId');
        _completarPendiente('');
        return null;
      }
      _flujoNavegador = true;
      try {
        unawaited(_lanzarNavegador(nombreMostrado, urlAuth));
        final grant = await callbackDesktop.esperarGrant(
            timeout ?? _timeoutGrant);
        _completarPendiente(grant);
        return grant;
      } finally {
        _flujoNavegador = false;
      }
    }

    // ── Intento silencioso ─────────────────────────────────────────────────
    // El challenge de Cloudflare suele ser un Turnstile en modo managed
    // (no-interactivo): dentro de un WebView real se auto-completa SOLO y el
    // grant llega sin que el usuario toque nada. Intentarlo primero en un
    // WebView oculto (1x1px, sin render visible) evita abrir el modal: la
    // sesión queda firmada en segundo plano y el usuario no ve NADA. Solo si
    // el challenge requiere interacción humana (o no auto-completa a tiempo)
    // se cae al dialog visible de abajo. El keepalive (cada 25s) ya refresca
    // las sesiones vivas; este intento cubre el caso de sesión vencida.
    // Saltado cuando [intentarAuto] es false (setup): ahí el usuario quiere
    // ver el sandbox de inmediato y no esperar la ventana silenciosa.
    if (intentarAuto) {
      final ctxSilencioso = _navigatorKey?.currentContext;
      if (ctxSilencioso != null) {
        final grantSilencioso =
            await _intentarSilencioso(urlAuth, ctxSilencioso);
        if (grantSilencioso != null && grantSilencioso.isNotEmpty) {
          _completarPendiente(grantSilencioso);
          debugPrint('[Verificacion] AUTO-firmado sin modal ✓ '
              '(${grantSilencioso.length} chars)');
          return grantSilencioso;
        }
      }
    }

    // Último recurso: dialog WebView visible.
    return _mostrarDialogoGrant(
      extId: extId,
      nombreMostrado: nombreMostrado,
      urlAuth: urlAuth,
      timeout: timeout ?? _timeoutGrant,
      completador: completador,
    );
  }
}
