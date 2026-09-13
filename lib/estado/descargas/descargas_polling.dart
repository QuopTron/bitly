// ─────────────────────────────────────────────────────────────
// descargas_polling.dart — PART de cubit_descargas.dart: arranque y
// mantenimiento de los timers del cubit: poll de progreso (3s,
// activo solo cuando hay descargas o limpieza pendiente), refresh
// del historial (30s, 10s cuando hay descargas activas) y el
// normalizador del campo `status` de Go (acepta entero y string —
// el tracker viejo marshaleaba Status como int y un cast duro
// dejaría todo naranja para siempre).
// Se conecta con: descargas_reparar_escaneo.dart (misma library).
// Parte del flujo: descargas (polling de progreso).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Timers de polling y refresh. Mixin aplicado en CubitDescargas.
mixin DescargasPolling on DescargasRepararEscaneo {
  /// El poll de progreso completo — implementación concreta en
  /// DescargasPollProgreso (arriba en la cadena).
  Future<void> _pollProgreso();

  /// Recarga del historial — implementación concreta en DescargasCarga
  /// (arriba en la cadena).
  Future<void> _cargarHistorial();

  void _asegurarPolling() {
    if (_timerProgreso == null || !_timerProgreso!.isActive) {
      _empezarPolling();
    }
  }

  void _empezarPolling() {
    _timerProgreso?.cancel();
    _timerProgreso = Timer.periodic(const Duration(seconds: 3), (_) {
      final hayActivas = state.descargas.values
          .any((d) => d.estado == EstadoDescarga.enProgreso);
      if (hayActivas || _rachaProgresoVacio > 0) {
        _pollProgreso();
      } else {
        // Sin descargas activas ni limpieza pendiente — parar el poll.
        _timerProgreso?.cancel();
        _timerProgreso = null;
      }
    });
  }

  void _empezarRefreshHistorial() {
    _timerHistorial?.cancel();
    _timerHistorial = Timer.periodic(const Duration(seconds: 30), (_) {
      _cargarHistorial().catchError((_) {});
    });
  }

  /// Reinicia el refresh del historial con intervalo adaptativo: 10s durante
  /// descargas activas, 30s en reposo.
  void _ajustarTasaRefreshHistorial() {
    final hayActivas = state.descargas.values
        .any((d) => d.estado == EstadoDescarga.enProgreso);
    final intervaloActual = _timerHistorial != null && _timerHistorial!.isActive
        ? const Duration(seconds: 30)
        : Duration.zero;
    final intervaloDeseado = hayActivas
        ? const Duration(seconds: 10)
        : const Duration(seconds: 30);
    if (intervaloActual != intervaloDeseado) {
      _timerHistorial?.cancel();
      _timerHistorial = Timer.periodic(intervaloDeseado, (_) {
        _cargarHistorial().catchError((_) {});
      });
    }
  }

  /// Normaliza el campo `status` de una entrada de progreso de Go. El tracker
  /// viejo marshaleaba Status como entero (0=queued … 5=cancelled), así que
  /// acepta AMBOS formatos. Un cast duro aquí lanzaría en el primer item de
  /// cada poll, se tragaría el catch y dejaría toda descarga naranja para
  /// siempre aunque el archivo existiera en disco.
  String _estadoDe(Map<String, dynamic> p) {
    final raw = p['status'];
    if (raw is String) return raw;
    if (raw is num) {
      switch (raw.toInt()) {
        case 0:
          return 'queued';
        case 1:
          return 'downloading';
        case 2:
          return 'processing';
        case 3:
          return 'completed';
        case 4:
          return 'failed';
        case 5:
          return 'cancelled';
      }
    }
    return '';
  }
}