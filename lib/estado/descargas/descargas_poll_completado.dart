// ─────────────────────────────────────────────────────────────
// descargas_poll_completado.dart — PART de cubit_descargas.dart:
// cabeza de la rama 'completed'/'finalizing' del poll: chequea si el
// item ya fue persistido en un poll anterior (resolviendo la carrera
// de proveedores donde un overwrite encriptado requiere re-decrypt),
// y delega el decrypt DRM en _desencriptarSiNecesario
// (descargas_poll_decrypt.dart) y la verificación/persistencia del
// archivo en _finalizarEstadoCompletado (descargas_poll_finalizar.dart).
// Se conecta con: descargas_poll_finalizar.dart (misma library).
// Parte del flujo: descargas (poll → items completados).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Rama completada del poll. Mixin aplicado en CubitDescargas.
mixin DescargasPollCompletado on DescargasPollPersistir {
  /// Decrypt DRM de un archivo descargado — implementación concreta en
  /// DescargasPollDecrypt (arriba en la cadena). Devuelve la ruta reproducible
  /// (o null si se manejó el caso internamente y NO hay que finalizar).
  Future<({String? rutaReproducible, bool continuar})> _desencriptarSiNecesario(
    String rawId,
    String stateKey,
    Map<String, dynamic> p,
    String playablePath,
    bool isSubTask,
    Map<String, DatosEstadoDescarga> dl,
  );

  /// Procesa una entrada con status completed/finalizing.
  /// Devuelve true si cambió el estado.
  Future<bool> _procesarItemCompletado(
    String rawId,
    String stateKey,
    Map<String, dynamic> p,
    Map<String, DatosEstadoDescarga> dl,
    Set<String> fps,
  ) async {
    final outputPath = (p['outputPath'] ?? p['file_path'] ?? '') as String;
    final encrypted = (p['encrypted'] ?? false) == true;
    final clientDecrypt = (p['clientDecrypt'] ?? false) == true;
    final decKey = (p['decryptionKey'] ?? '').toString();
    // Solo persistir a BD y guardar carátula para la completación BASE (audio).
    // Las subtareas (letras/video) tienen su propio evento de completación pero
    // su stateKey es de subtarea (p.ej. track_123_deezer_lyrics) donde
    // _metaTrack no tiene entrada — produciría un trackId incorrecto.
    final isSubTask = stateKey.endsWith('_lyrics') || stateKey.endsWith('_video');

    // Ya persistido en un poll anterior (Go reporta los items completados
    // indefinidamente): solo mantener el estado visual. El path del tracker ya
    // es el definitivo (Go marca "completed" después del finalize).
    if (!isSubTask && _completadosPersistidos.contains(rawId)) {
      // Fix de carrera de proveedores: cuando SoundCloud completa primero
      // (no encriptado) y Amazon luego sobreescribe el archivo con un FLAC
      // encriptado, el poll debe reprocesar el item para correr el decrypt.
      // Sin esto, el archivo encriptado queda en disco pero el track sigue
      // "completed" con un archivo no reproducible.
      if (_carreraResuelta.contains(rawId)) return false;
      if (encrypted && clientDecrypt && decKey.isNotEmpty &&
          !_decryptClienteHecho.contains(rawId) &&
          !_decryptClienteSaltado.contains(rawId)) {
        // Antes de reprocesar, chequear si el archivo actual en disco sigue
        // siendo reproducible. Si el .mp3 de SoundCloud es válido, no dejar
        // que el overwrite encriptado de Amazon dispare un re-decrypt que
        // podría degradar el track a interrumpido.
        if (outputPath.isNotEmpty) {
          try {
            final curFile = File(outputPath);
            if (await curFile.exists() && await _esAudioDecodificable(curFile)) {
              _log.i('[poll] $rawId: carrera de proveedores pero el archivo actual sigue siendo reproducible — saltando re-proceso');
              _carreraResuelta.add(rawId);
              return false;
            }
          } catch (_) {}
        }
        // El archivo fue sobreescrito por un proveedor en carrera con una
        // versión encriptada — pero primero chequear si existe una alternativa.
        final raceAlt = await _buscarArchivoAlternativo(stateKey, outputPath);
        if (raceAlt != null) {
          _log.i('[poll] $rawId: carrera de proveedores pero se encontró alternativa: $raceAlt — manteniendo completado');
          _carreraResuelta.add(rawId);
          // Actualizar el path de BD para que _verificarArchivoDescargado de
          // la cola no falle al chequear el path encriptado (ahora obsoleto).
          try {
            final meta = _metaTrack[stateKey];
            final nid = meta != null && meta.trackId.isNotEmpty ? meta.trackId : stateKey;
            await _downloadCache.actualizarRutaArchivo(nid, raceAlt);
          } catch (_) {}
          return false;
        }
        // Sin alternativa — quitar de persistidos para que el decrypt corra abajo.
        _log.i('[poll] reprocesando $rawId: archivo sobreescrito con versión encriptada (carrera de proveedores)');
        _completadosPersistidos.remove(rawId);
      } else {
        return false;
      }
    }

    // Descarga encriptada/DRM con clave de desencriptado y sin CLI ffmpeg en
    // el backend (Android): desencriptar aquí vía ffmpeg-kit — el mismo paso
    // que el flujo de streaming — antes de persistir un archivo reproducible.
    // Si no, el archivo guardado es un stream encriptado no reproducible.
    var playablePath = outputPath;
    if (!isSubTask && playablePath.isNotEmpty && encrypted && clientDecrypt && decKey.isNotEmpty) {
      final resultado = await _desencriptarSiNecesario(rawId, stateKey, p, playablePath, isSubTask, dl);
      if (!resultado.continuar) return true;
      playablePath = resultado.rutaReproducible ?? playablePath;
    }

    return _finalizarEstadoCompletado(rawId, stateKey, p, dl, fps, playablePath, isSubTask);
  }
}