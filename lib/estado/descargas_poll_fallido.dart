// ─────────────────────────────────────────────────────────────
// descargas_poll_fallido.dart — PART de cubit_descargas.dart:
// manejo de items con status 'failed'/'cancelled' en el poll. Si el
// track es el actual de la cola FIFO, Go puede reportar fallo pero
// un proveedor (Apple Music .m4a, SoundCloud .mp3) puede haber
// escrito un archivo reproducible — se persiste como completado.
// Sin archivo, se cuenta el ciclo y tras [_maxPollFallidosSinArchivo]
// la cola abandona y pasa al siguiente track.
// Se conecta con: descargas_track.dart (misma library).
// Parte del flujo: descargas (poll de progreso → items fallidos).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Manejo de items fallidos del poll. Mixin aplicado en CubitDescargas.
mixin DescargasPollFallido on DescargasTrack {
  /// Procesa una entrada de progreso con status failed/cancelled.
  /// Devuelve true si cambió el estado.
  Future<bool> _procesarItemFallido(
    String rawId,
    String stateKey,
    Map<String, dynamic> p,
    Map<String, DatosEstadoDescarga> dl,
  ) async {
    // Saltar si ya se procesó en un ciclo anterior.
    if (_completadosPersistidos.contains(rawId)) return false;
    final outputPath = (p['outputPath'] ?? p['file_path'] ?? '') as String;
    if (stateKey == _idTrackActualCola) {
      // Go reporta failed pero la cola FIFO sigue esperando. Chequear si algún
      // proveedor ya escribió un archivo reproducible en disco.
      String? playableAlt;
      // Fast path 1: si outputPath apunta a un archivo reproducible existente.
      if (outputPath.isNotEmpty) {
        try {
          final opFile = File(outputPath);
          if (await opFile.exists() && await _esAudioDecodificable(opFile)) {
            playableAlt = outputPath;
            _log.i('[poll] $rawId: Go reporta failed pero outputPath es reproducible: $outputPath — persistiendo');
          }
        } catch (_) {}
        // Fast path 1b: outputPath puede ser .tmp.XXX (antes del rename finalize).
        if (playableAlt == null && outputPath.contains('.tmp.')) {
          try {
            final nonTmp = outputPath.replaceFirst('.tmp.', '.');
            final ntFile = File(nonTmp);
            if (await ntFile.exists() && await _esAudioDecodificable(ntFile)) {
              playableAlt = nonTmp;
              _log.i('[poll] $rawId: Go reporta failed pero el path non-tmp es reproducible: $nonTmp — persistiendo');
            }
          } catch (_) {}
        }
      }
      // Fast path 2: escanear el directorio buscando un archivo alternativo.
      playableAlt ??= await _buscarArchivoAlternativo(stateKey, outputPath);
      if (playableAlt != null) {
        _fallidosSinArchivoCount.remove(rawId);
        _log.i('[poll] $rawId: Go reporta failed pero se encontró alternativa: $playableAlt — persistiendo como completado');
        try {
          final meta = _metaTrack[stateKey];
          final nid = meta != null && meta.trackId.isNotEmpty ? meta.trackId : stateKey;
          // guardarTrackDescargado (INSERT OR REPLACE) asegura la fila —
          // actualizarRutaArchivo sería un no-op silencioso si la fila no existe.
          await _downloadCache.guardarTrackDescargado(
            id: nid, trackName: meta?.name ?? '', artistName: meta?.artist ?? '',
            filePath: playableAlt, service: meta?.source ?? '',
          );
        } catch (_) {}
        _completadosPersistidos.add(rawId);
        dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
        _senializarTrackTerminado(stateKey);
        return true;
      }
      // Sin archivo reproducible aún — un proveedor puede seguir escribiendo.
      final count = (_fallidosSinArchivoCount[rawId] ?? 0) + 1;
      _fallidosSinArchivoCount[rawId] = count;
      if (count >= _maxPollFallidosSinArchivo) {
        _log.w('[poll] $rawId: Go reporta failed tras $count polls — sin archivo, abandonando');
        _fallidosSinArchivoCount.remove(rawId);
        dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido, progreso: 0.0);
        _completadosPersistidos.add(rawId);
        _senializarTrackTerminado(stateKey);
      } else {
        _log.i('[poll] $rawId: Go reporta failed pero la cola está activa — sin archivo aún ($count/$_maxPollFallidosSinArchivo), manteniendo enProgreso (outputPath=$outputPath)');
        dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.enProgreso, progreso: 0.95);
      }
      return true;
    }
    dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido, progreso: 0.0);
    _iniciadosEn.remove(stateKey);
    _senializarTrackTerminado(stateKey);
    return true;
  }
}