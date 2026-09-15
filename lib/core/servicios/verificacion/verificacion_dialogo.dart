// ─────────────────────────────────────────────────────────────
// verificacion_dialogo.dart — PART de servicio_verificacion.dart:
// el dialog WebView VISIBLE del challenge. Arma el
// DialogoVerificacion, el timer de timeout, el puente con el
// servidor loopback de Windows y el fallback al navegador.
// Se conecta con: servicio_verificacion.dart (misma library) +
// dialogo_verificacion + servidor_callback_escritorio.
// Parte del flujo: verificación de sesiones (challenge visible).
// ─────────────────────────────────────────────────────────────

part of 'servicio_verificacion.dart';

/// Dialog WebView del challenge. Mixin aplicado en ServicioVerificacion.
mixin VerificacionDialogo on VerificacionNavegador {
  /// Abre el dialog WebView del challenge y espera el grant. Si no hay
  /// contexto de UI, cae al navegador del sistema. Devuelve el futuro del
  /// [completador] compartido con el flujo que lo invocó.
  Future<String?> _mostrarDialogoGrant({
    required String extId,
    required String nombreMostrado,
    required String urlAuth,
    required Duration timeout,
    required Completer<String?> completador,
  }) async {
    NavigatorState? dialogNav;
    final callbackDesktop = ServidorCallbackEscritorio.instance;

    _timeout = Timer(timeout, () {
      _logVerificacion.w('[Verificacion] Verificación agotó el tiempo tras '
          '${timeout.inMinutes} min');
      _completarPendiente('');
      // Pop solo de la ruta del dialog Y solo mientras el dialog esté abierto.
      // Un Navigator.pop() ciego al timeout puede popear la última página del
      // root de go_router y crashear con 'popped the last page off of the stack'.
      final nav = dialogNav;
      if (nav != null && nav.mounted && nav.canPop() && _dialogoAbierto) {
        nav.pop();
      }
    });

    final ctx = _navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) {
      // Sin contexto de UI disponible — fallback al navegador del sistema.
      unawaited(_lanzarNavegador(nombreMostrado, urlAuth));
      return completador.future;
    }

    _dialogoAbierto = true;
    try {
      await showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) {
          dialogNav = Navigator.of(dialogCtx);

          void terminar(String? grant) {
            _completarPendiente(grant);
            debugPrint('[Verificacion] terminar($grant) mounted=${dialogCtx.mounted} '
                'canPop=${dialogCtx.mounted ? Navigator.of(dialogCtx).canPop() : false}');
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
          }

          // Windows: el callback del challenge apunta al servidor loopback local
          // (http://127.0.0.1:<puerto>/session-grant). Si el WebView embebido no
          // captura el grant por URL/JS (p.ej. WebView2 no disponible), el
          // servidor loopback lo recibe igual — conectarlo para cerrar el dialog
          // y completar la verificación por ese camino.
          if (Platform.isWindows && callbackDesktop.estaListo) {
            unawaited(() async {
              final grant = await callbackDesktop.esperarGrant(timeout);
              debugPrint('[Verificacion] loopback esperó grant → '
                  '${grant == null ? 'null' : grant.isNotEmpty ? 'OK' : 'vacío'}');
              if (grant != null && grant.isNotEmpty) {
                _completarPendiente(grant);
                if (dialogCtx.mounted && Navigator.of(dialogCtx).canPop()) {
                  Navigator.of(dialogCtx).pop();
                }
              }
            }());
          }

          return DialogoVerificacion(
            nombreMostrado: nombreMostrado,
            urlAuth: urlAuth,
            alObtenerGrant: terminar,
            alCancelar: () => terminar(null),
            alUsarNavegador: () {
              // Mantener el completer pendiente; el grant llega por deep link
              // (móvil) o por el servidor loopback (Windows/Linux).
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              unawaited(_lanzarNavegador(nombreMostrado, urlAuth));
            },
          );
        },
      );
    } finally {
      _dialogoAbierto = false;
    }

    return completador.future;
  }
}
