// ─────────────────────────────────────────────────────────────
// verificacion_ui.dart — PART de servicio_verificacion.dart:
// integración con el UI lifecycle (didChangeAppLifecycleState),
// avisos SnackBar y el omitirTodo que desbloquea la app. Separado
// del archivo principal para mantener el límite de líneas.
// Se conecta con: servicio_verificacion.dart (misma library).
// Parte del flujo: verificación de sesiones (UI/lifecycle).
// ─────────────────────────────────────────────────────────────

part of 'servicio_verificacion.dart';

/// UI y lifecycle de la verificación. Mixin aplicado en ServicioVerificacion.
/// Depende de VerificacionLote para poder disparar el re-intento silencioso de
/// fuentes pendientes al volver la app al primer plano.
mixin VerificacionUi on VerificacionLote {
  /// Omite la verificación pendiente y deshabilita más prompts de modal/
  /// navegador en esta corrida, para que la app nunca quede bloqueada.
  void omitirTodo() {
    _deshabilitado = true;
    ServidorCallbackEscritorio.instance.cancelar();
    _completarPendiente('');
  }

  /// Maneja el cambio de lifecycle: delega al keepalive y, al volver de
  /// background desde el navegador del sistema sin grant aún, cancela con un
  /// corto período de gracia (fallar rápido en vez del timeout completo).
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    _onLifecycle(estado);

    // Al volver al primer plano, si quedaron fuentes sin verificar (y no hay
    // dialog abierto), reintentarlas SILENCIOSAMENTE: el store de cookies ya
    // puede tener cf_clearance y las managed auto-pasan sin modal.
    if (estado == AppLifecycleState.resumed &&
        !_deshabilitado &&
        !_dialogoAbierto &&
        _pendiente == null &&
        _necesitaVerificacion.isNotEmpty) {
      unawaited(reintentarPendientesSilencioso());
    }

    // El usuario volvió del navegador del sistema (fallback browser). Si el
    // deep link del grant aún no llegó, darle un corto período de gracia; si
    // no, fallar rápido en vez de esperar el timeout completo.
    // Skip cuando el dialog WebView está abierto: significa que el usuario
    // solo backgrounded/volvió sin usar el navegador, así la verificación
    // debe seguir corriendo en el dialog.
    if (estado != AppLifecycleState.resumed) return;
    final pendiente = _pendiente;
    if (pendiente == null || _dialogoAbierto || _flujoNavegador) return;
    Timer(_graciaResume, () {
      if (identical(pendiente, _pendiente)) _completarPendiente('');
    });
  }

  /// Muestra un aviso corto sin acciones en el contexto actual. Se usa para
  /// superficiar fallos de reproducción que de otro modo serían silenciosos
  /// (p.ej. "Sesión de Deezer no verificada").
  void mostrarAviso(String mensaje) {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 4),
      ));
  }
}