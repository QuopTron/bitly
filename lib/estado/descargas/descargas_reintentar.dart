// ─────────────────────────────────────────────────────────────
// descargas_reintentar.dart — PART de cubit_descargas.dart:
// reintento de los tracks fallidos (no completados) de un lote de
// álbum/playlist. Reusa los datos originales guardados en
// _datosLote, limpia TODO el estado de poll del track (decrypt,
// persistencia, carrera, redescarga) para que el reintento procese
// desde cero y lo re-encola en la cola secuencial FIFO.
// Se conecta con: descargas_cola_verificar.dart (misma library).
// Parte del flujo: descargas (reintentos manuales y automáticos).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Reintento de tracks fallidos de un lote. Mixin aplicado en CubitDescargas.
mixin DescargasReintentar on DescargasColaVerificar {
  /// Reintenta solo los tracks fallidos (no completados) de un lote previo.
  /// [batchKey] debe coincidir con la key usada en iniciarDescargaAlbum o
  /// iniciarDescargaPlaylist (p.ej. "album_123_spotify").
  void reintentarTracksFallidosLote(String batchKey) {
    final data = _datosLote[batchKey];
    if (data == null) return;
    if (state.descargas[batchKey]?.estado == EstadoDescarga.enProgreso) return;

    // Encontrar qué tracks NO están completados.
    final fallidos = <Map<String, dynamic>>[];
    for (final t in data.tracks) {
      final tid = (t['track_id'] as String?) ?? '';
      if (tid.isEmpty) continue;
      final audioId = 'track_${normalizarId(tid)}_${data.source}';
      if (state.descargas[audioId]?.estado != EstadoDescarga.completado) {
        fallidos.add(t);
      }
    }
    if (fallidos.isEmpty) return;

    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    final audioIds = <String>[];
    for (final t in fallidos) {
      final tid = (t['track_id'] as String?) ?? '';
      if (tid.isEmpty) continue;
      final normalizedTid = normalizarId(tid);
      final audioId = 'track_${normalizedTid}_${data.source}';
      audioIds.add(audioId);
      // Pre-sembrar como enCola; _procesarColaDescargas lo pasa a enProgreso
      // cuando llega al frente de la fila FIFO.
      dl[audioId] = const DatosEstadoDescarga(estado: EstadoDescarga.enCola, progreso: 0.0);
      // Limpiar TODO el estado de poll para que el reintento procese desde
      // cero. Sin esto, _completadosPersistidos haría que el poll salte la
      // nueva entrada del tracker (mismo rawId).
      final retryRawId = '${normalizedTid}_audio';
      _decryptClienteSaltado.remove(retryRawId);
      _decryptClienteHecho.remove(retryRawId);
      _fallosDecryptCount.remove(retryRawId);
      _completadosPersistidos.remove(retryRawId);
      _carreraResuelta.remove(retryRawId);
      _colaRedescarga.remove(audioId);
      // Ruta a través de la cola FIFO global — despachar directo aquí
      // disparaba reintentos en paralelo rompiendo el orden uno-a-la-vez.
      _colaDescargas.add(_TrackEnCola(
          t, tid, data.source, data.ajustes, data.calidadForzada, batchKey));
    }

    _batchTrackIds[batchKey] = audioIds;
    dl[batchKey] = const DatosEstadoDescarga(estado: EstadoDescarga.enProgreso, progreso: 0.0);
    emit(state.copiarCon(descargas: dl));
    _procesarColaDescargas();
  }
}