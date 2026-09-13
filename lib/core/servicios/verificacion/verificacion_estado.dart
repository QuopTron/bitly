// ─────────────────────────────────────────────────────────────
// verificacion_estado.dart — PART de servicio_verificacion.dart:
// estado compartido de la verificación (completer pendiente, timer
// de timeout, flags de dialog/deshabilitado/navegador) y helpers de
// completado/limpieza del grant. Los mixins keepalive y mostrar lo
// usan vía `on VerificacionEstado`.
// Se conecta con: servicio_verificacion.dart (misma library).
// Parte del flujo: verificación de sesiones (estado compartido).
// ─────────────────────────────────────────────────────────────

part of 'servicio_verificacion.dart';

/// Estado compartido de la verificación de sesiones firmadas.
mixin VerificacionEstado {
  GlobalKey<NavigatorState>? _navigatorKey;

  // Solo una verificación pendiente a la vez (setup, búsqueda y descargas
  // procesan proveedores secuencialmente).
  Completer<String?>? _pendiente;
  Timer? _timeout;
  bool _dialogoAbierto = false;

  // Fuentes que el último provision encontró necesitando challenge humano
  // (nunca se auto-abren — los flujos de acción explícita preguntan bajo
  // demanda).
  final Set<String> _necesitaVerificacion = {};
  bool _deshabilitado = false;
  bool _runActivo = false;
  // True mientras corre el flujo de navegador desktop (el grant llega por el
  // servidor HTTP local, no por el deep link). Suprime el auto-cancel del
  // resume para que el usuario pueda volver a la app antes de completar.
  bool _flujoNavegador = false;

  bool get estaListo => _navigatorKey != null;

  void _completarPendiente(String? grant) {
    final c = _pendiente;
    _pendiente = null;
    _timeout?.cancel();
    _timeout = null;
    if (c != null && !c.isCompleted) {
      final g = grant?.trim() ?? '';
      c.complete(g.isEmpty ? null : _limpiarGrant(g));
    }
  }

  String _limpiarGrant(String crudo) {
    final g = crudo.trim();
    if (g.startsWith('grant=')) return g.substring(6);
    return g;
  }
}