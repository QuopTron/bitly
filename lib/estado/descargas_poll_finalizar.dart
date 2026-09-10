// ─────────────────────────────────────────────────────────────
// descargas_poll_finalizar.dart — PART de cubit_descargas.dart:
// cola de la rama 'completed' del poll: verifica por magic bytes
// que el archivo sea reproducible (rechazando .tmp.XXX y buscando
// alternativas), actualiza las keys hermanas de subtareas, señala
// a la cola o cuenta polls de espera (hasta 4 ~12s) y delega la
// persistencia en descargas_poll_persistir.dart.
// Se conecta con: descargas_poll_fallido.dart (misma library).
// Parte del flujo: descargas (poll → persistencia de completados).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Finalización de items completados. Mixin aplicado en CubitDescargas.
mixin DescargasPollFinalizar on DescargasPollFallido {
  /// Persistencia del track completado — impl. en DescargasPollPersistir.
  Future<void> _persistirCompletado(
    String rawId,
    String stateKey,
    String playablePath,
    String trackName,
    String artistName,
    Set<String> fps,
  );

  /// Cola de la rama completada: verificación de archivo + persistencia.
  Future<bool> _finalizarEstadoCompletado(
    String rawId,
    String stateKey,
    Map<String, dynamic> p,
    Map<String, DatosEstadoDescarga> dl,
    Set<String> fps,
    String playablePath,
    bool isSubTask,
  ) async {
    // Verificar que el archivo sea audio reproducible antes del punto verde
    // (Go puede reportar completado con un archivo corrupto/encriptado).
    final trackName = (p['track_name'] ?? '') as String;
    final artistName = (p['artist_name'] ?? '') as String;
    var filePlayable = true;
    if (!isSubTask && playablePath.isNotEmpty) {
      try {
        final pf = File(playablePath);
        if (await pf.exists()) {
          filePlayable = await _esAudioDecodificable(pf);
          if (!filePlayable) {
            _log.w('[poll] $rawId: Go dice completado pero el archivo no es reproducible: $playablePath');
          }
        } else {
          filePlayable = false;
          _log.w('[poll] $rawId: Go dice completado pero falta el archivo: $playablePath');
        }
      } catch (_) {}
    }
    if (!filePlayable) {
      // El tracker de Go guarda .tmp.XXX como outputPath antes de que el
      // finalize renombre a .XXX. Chequear el path non-tmp primero.
      if (playablePath.isNotEmpty) {
        final tmpIdx = playablePath.indexOf('.tmp.');
        if (tmpIdx >= 0) {
          final nonTmpPath = playablePath.replaceFirst('.tmp.', '.');
          try {
            final ntFile = File(nonTmpPath);
            if (await ntFile.exists() && await _esAudioDecodificable(ntFile)) {
              _log.i('[poll] $rawId: falta el .tmp pero existe el non-tmp: $nonTmpPath — usándolo');
              playablePath = nonTmpPath;
              filePlayable = true;
              _completadosSinArchivoCount.remove(rawId);
              try {
                final meta = _metaTrack[stateKey];
                final nid = meta != null && meta.trackId.isNotEmpty ? meta.trackId : stateKey;
                await _downloadCache.actualizarRutaArchivo(nid, nonTmpPath);
              } catch (_) {}
            }
          } catch (_) {}
        }
      }
    }
    if (!filePlayable) {
      // Archivo no reproducible — buscar alternativas de otros proveedores que
      // hayan guardado un archivo válido junto al roto.
      final altPath = await _buscarArchivoAlternativo(stateKey, playablePath);
      if (altPath != null) {
        _log.i('[poll] $rawId: archivo no reproducible pero existe alternativa: $altPath — usándola');
        playablePath = altPath;
        filePlayable = true;
        _completadosSinArchivoCount.remove(rawId);
        try {
          final meta = _metaTrack[stateKey];
          final nid = meta != null && meta.trackId.isNotEmpty ? meta.trackId : stateKey;
          await _downloadCache.actualizarRutaArchivo(nid, altPath);
        } catch (_) {}
      }
    }
    if (filePlayable) {
      dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
    } else {
      if (stateKey == _idTrackActualCola) {
        _log.i('[poll] $rawId: archivo no reproducible pero la cola está activa — manteniendo enProgreso');
        dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.enProgreso, progreso: 0.95);
      } else {
        dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido, progreso: 0.0);
        _errorDesencriptadoPendiente = 'decrypt';
      }
    }
    // Actualizar keys hermanas de subtareas (audio/letras/video) si existen.
    final audioKey = '${stateKey}_audio';
    if (dl.containsKey(audioKey)) {
      dl[audioKey] = filePlayable
          ? const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0)
          : const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido, progreso: 0.0);
    }
    final lyricsKey = '${stateKey}_lyrics';
    if (dl.containsKey(lyricsKey)) {
      dl[lyricsKey] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
    }
    final videoKey = '${stateKey}_video';
    if (dl.containsKey(videoKey)) {
      dl[videoKey] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
    }

    // Señalar a la cola secuencial que este track terminó. PERO: si el archivo
    // existe pero aún no es reproducible (p.ej. el .mp3 de SoundCloud llegó
    // pero el .m4a de Apple Music no se finalizó), no señalar — seguir
    // polling para darle tiempo al .m4a.
    if (!isSubTask) {
      if (filePlayable) {
        _senializarTrackTerminado(stateKey);
      } else {
        final noFileCount = _completadosSinArchivoCount[rawId] ?? 0;
        _completadosSinArchivoCount[rawId] = noFileCount + 1;
        if (noFileCount >= 4) {
          _log.w('[poll] $rawId: archivo no reproducible tras ${noFileCount + 1} polls, abandonando');
          _completadosSinArchivoCount.remove(rawId);
          dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido, progreso: 0.0);
          _completadosPersistidos.add(rawId);
          _senializarTrackTerminado(stateKey);
        } else {
          _log.i('[poll] $rawId: archivo no reproducible, esperando alternativa (${noFileCount + 1}/4)');
        }
      }
    }

    // Persistir solo la completación BASE (audio) — impl. en PollPersistir.
    if (!isSubTask) {
      await _persistirCompletado(rawId, stateKey, playablePath, trackName, artistName, fps);
    }
    _iniciadosEn.remove(stateKey);
    return true;
  }
}