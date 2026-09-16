// ─────────────────────────────────────────────────────────────
// descargas_cola.dart — PART de cubit_descargas.dart: el bucle de la
// cola secuencial (FIFO estricto, un track a la vez). NO avanza el
// orden cuando la canción falla: la reencola al FRENTE con la calidad
// degradada un escalón (descargas_cola_reintento.dart) hasta agotar
// los reintentos. El trabajo de un track vive en
// descargas_cola_track.dart.
// Se conecta con: descargas_cola_reintento.dart y descargas_cola_track.dart.
// Parte del flujo: descargas (cola secuencial).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Orquestador de la cola. Mixin aplicado en CubitDescargas.
mixin DescargasCola on DescargasColaReintento {
  /// Despacho de un track dentro de un lote — implementación concreta en
  /// DescargasTrack (arriba en la cadena).
  void _despacharTrackLote(
    Map<String, dynamic> trackMap,
    String trackId,
    String source,
    AjustesDescarga ajustes, {
    String? calidadForzada,
  });

  /// Procesamiento de un track — implementación concreta en DescargasColaTrack
  /// (arriba en la cadena).
  Future<bool> _procesarTrackDeCola(_TrackEnCola track, String baseId);

  /// Procesa la cola global un track a la vez. Los lotes se procesan en FIFO:
  /// primero todos los tracks del lote 1, luego los del lote 2, etc. Un track
  /// que falla se reintenta a SÍ MISMO (con calidad degradada) antes de que el
  /// orden avance, para no dejar atrás una canción que sí se puede bajar.
  @override
  Future<void> _procesarColaDescargas() async {
    if (_procesandoCola || _colaDescargas.isEmpty) return;
    _procesandoCola = true;

    while (_colaDescargas.isNotEmpty) {
      final track = _colaDescargas.removeAt(0);
      final baseId = 'track_${normalizarId(track.trackId)}_${track.source}';
      final ok = await _procesarTrackDeCola(track, baseId);
      if (ok) {
        _olvidarIntentos(baseId);
        continue;
      }
      // Solo se reintenta un fallo recuperable por la app (red/proveedor).
      // Un corte que necesita al usuario (gate free, carpeta sin permiso) no
      // se reencola: repetiría el mismo aviso sin cambiar nada.
      if (_falloReintentable && _debeReintentarTrack(baseId)) {
        _reencolarConReintento(track, baseId);
        continue;
      }
      _log.w('[cola] ✖ $baseId agotó $_maxReintentosInSitu reintento(s) — '
          'queda interrumpido y el FIFO avanza');
      _olvidarIntentos(baseId);
    }

    _idTrackActualCola = null;
    _procesandoCola = false;
    _intentosPorTrack.clear();
    _log.i('[cola] ═══ COLA VACÍA ═══');
  }
}
