// ─────────────────────────────────────────────────────────────
// descargas_cola_reintento.dart — PART de cubit_descargas.dart:
// reintento EN SITIO dentro de la cola FIFO. Una canción que falla
// no deja avanzar el orden: se reencola al FRENTE con la calidad
// degradada un escalón (FLAC → MP3_320 → MP3_128) hasta agotar
// [_maxReintentosInSitu]. Antes de reencolarla se limpia su estado
// de poll para que el intento nuevo sea real y no lo saltee el
// marcador de "ya persistido".
// Se conecta con: descargas_cola.dart (usa estos helpers).
// Parte del flujo: descargas (cola secuencial).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Reintento en sitio de la cola. Mixin aplicado en CubitDescargas.
mixin DescargasColaReintento on DescargasReintentar {
  /// Reintentos ya consumidos por [baseId] (0 = solo el intento original).
  int _intentoActual(String baseId) => _intentosPorTrack[baseId] ?? 0;

  /// ¿Todavía corresponde reintentar esta canción antes de avanzar el FIFO?
  bool _debeReintentarTrack(String baseId) =>
      _intentoActual(baseId) < _maxReintentosInSitu;

  /// Descuenta un reintento de [baseId] y devuelve el intento que viene.
  int _registrarIntento(String baseId) {
    final siguientes = _intentoActual(baseId) + 1;
    _intentosPorTrack[baseId] = siguientes;
    return siguientes;
  }

  /// Olvida los reintentos de un track (completó, o se agotaron).
  void _olvidarIntentos(String baseId) => _intentosPorTrack.remove(baseId);

  /// ¿El último fallo marcado se puede intentar de nuevo (otra calidad/fuente)
  /// o hay que esperar al usuario?
  bool _falloReintentable = false;

  /// Marca [baseId] como interrumpido con un motivo visible para la UI.
  /// [reintentable] distingue un fallo de red/proveedor (vale reintentar solo)
  /// de uno que necesita al usuario (gate del plan free, carpeta sin permiso):
  /// reintentar el segundo solo repetiría el mismo aviso.
  void _marcarInterrumpido(
    String baseId,
    String motivo, {
    bool reintentable = true,
  }) {
    _falloReintentable = reintentable;
    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    dl[baseId] = DatosEstadoDescarga(
      estado: EstadoDescarga.interrumpido,
      progreso: 0.0,
      mensajeError: motivo,
    );
    emit(state.copiarCon(descargas: dl));
  }

  /// Reencola la MISMA canción al frente de la cola con la calidad del
  /// siguiente intento. Es lo que garantiza que el FIFO no saltee una canción
  /// recuperable: el orden recién avanza cuando esta se descarga de verdad o
  /// cuando se agotan los reintentos.
  void _reencolarConReintento(_TrackEnCola track, String baseId) {
    final n = _registrarIntento(baseId);
    final calidad = calidadParaIntento(
      forzada: track.calidadForzada,
      calidadAjustes: track.ajustes.calidadAudio,
      intento: n + 1,
    );
    // Estado de poll limpio: sin esto _completadosPersistidos haría que el poll
    // saltee la entrada nueva del tracker (mismo rawId) y el reintento no
    // volvería a descargar nada.
    _limpiarEstadoPollTrack(normalizarId(track.trackId), baseId);
    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    dl[baseId] = const DatosEstadoDescarga(
      estado: EstadoDescarga.enCola,
      progreso: 0.0,
    );
    emit(state.copiarCon(descargas: dl));
    _log.w(
      '[cola] ↻ REINTENTO ${n + 1}/${_maxReintentosInSitu + 1} de $baseId '
      'con calidad=${calidad ?? "la configurada"} — el FIFO NO avanza',
    );
    _colaDescargas.insert(
      0,
      _TrackEnCola(
        track.trackMap,
        track.trackId,
        track.source,
        track.ajustes,
        calidad,
        track.batchKey,
      ),
    );
  }
}
