// ─────────────────────────────────────────────────────────────
// descargas_poll_decrypt.dart — PART de cubit_descargas.dart:
// decrypt DRM de un item 'completed' con flag encriptado. Primero
// valida por magic bytes que el archivo no sea ya reproducible
// (FAST PATH: el flag puede ser de un proveedor en carrera), luego
// busca una alternativa en disco antes del decrypt lento, y solo
// como SLOW PATH corre ffmpeg-kit con timeout de 90s y hasta
// [_maxReintentosDecrypt] reintentos (los fallos transitorios de
// ffmpeg-kit son comunes en emuladores).
// Se conecta con: descargas_poll_completado.dart (misma library).
// Parte del flujo: descargas (poll → decrypt de streams DRM).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Decrypt de items completados. Mixin aplicado en CubitDescargas.
mixin DescargasPollDecrypt on DescargasPollCompletado {
  /// Decide si el archivo necesita decrypt y lo ejecuta si hace falta.
  /// Devuelve la ruta reproducible final, o continuar=false cuando el caso se
  /// manejó internamente (reintento pendiente / fallo definitivo) y el
  /// llamador NO debe finalizar.
  @override
  Future<({String? rutaReproducible, bool continuar})> _desencriptarSiNecesario(
    String rawId,
    String stateKey,
    Map<String, dynamic> p,
    String playablePath,
    bool isSubTask,
    Map<String, DatosEstadoDescarga> dl,
  ) async {
    final decKey = (p['decryptionKey'] ?? '').toString();
    final outExt = (p['outputExtension'] ?? '').toString();
    final inputFormat = (p['inputFormat'] ?? '').toString();
    if (_decryptClienteHecho.contains(rawId) || _decryptClienteSaltado.contains(rawId)) {
      // Ya desencriptado (o falló) en un poll anterior — nunca reprocesar la
      // misma entrada del tracker.
      return (rutaReproducible: playablePath, continuar: true);
    }
    return _desencriptarConReintentos(
      rawId, stateKey, decKey, outExt, inputFormat, playablePath, dl);
  }

  /// Corrida real del decrypt con los fast paths y reintentos.
  Future<({String? rutaReproducible, bool continuar})> _desencriptarConReintentos(
    String rawId,
    String stateKey,
    String decKey,
    String outExt,
    String inputFormat,
    String playablePath,
    Map<String, DatosEstadoDescarga> dl,
  ) async {
    // FAST PATH: antes de intentar un decrypt lento, chequear si el archivo
    // en outputPath ya es reproducible (p.ej. .m4a de Apple Music mientras el
    // flag encriptado es de Amazon).
    try {
      final probeFile = File(playablePath);
      if (await probeFile.exists() && await _esAudioDecodificable(probeFile)) {
        _log.i('[poll] $rawId: flag encriptado pero el archivo ya es reproducible: $playablePath — saltando decrypt');
        _decryptClienteHecho.add(rawId);
        _fallosDecryptCount.remove(rawId);
        return (rutaReproducible: playablePath, continuar: true);
      }
    } catch (_) {}
    // FAST PATH 2: si el archivo encriptado NO es reproducible, chequear si
    // otro proveedor ya guardó un archivo reproducible (p.ej. Apple Music
    // .m4a, SoundCloud .mp3) ANTES de intentar el decrypt lento con
    // ffmpeg-kit. Evita timeouts de 90s×3 en emuladores cuando existe una
    // alternativa perfectamente buena.
    final altPath = await _buscarArchivoAlternativo(stateKey, playablePath);
    if (altPath != null) {
      _log.i('[poll] $rawId: archivo encriptado no reproducible pero se encontró alternativa: $altPath — saltando decrypt');
      _decryptClienteHecho.add(rawId);
      _fallosDecryptCount.remove(rawId);
      try {
        final meta = _metaTrack[stateKey];
        final nid = meta != null && meta.trackId.isNotEmpty ? meta.trackId : stateKey;
        await _downloadCache.actualizarRutaArchivo(nid, altPath);
      } catch (_) {}
      return (rutaReproducible: altPath, continuar: true);
    }
    // SLOW PATH: solo intentar el decrypt si no se encontró archivo reproducible.
    final decrypted = await _desencriptarArchivoDescargado(playablePath, decKey, outExt, inputFormat)
        .timeout(const Duration(seconds: 90), onTimeout: () {
      _log.e('[poll] decrypt expiró tras 90s para $rawId');
      return null;
    });
    if (decrypted == null || decrypted.isEmpty) {
      final attempts = (_fallosDecryptCount[rawId] ?? 0) + 1;
      _fallosDecryptCount[rawId] = attempts;
      _iniciadosEn.remove(stateKey);
      if (attempts < _maxReintentosDecrypt) {
        _log.w('[poll] decrypt falló para $rawId (intento $attempts/$_maxReintentosDecrypt), se reintentará el próximo poll');
        dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.enProgreso, progreso: 0.95);
        return (rutaReproducible: null, continuar: false);
      }
      // Reintentos agotados — buscar alternativa o marcar interrumpido.
      if (stateKey != _idTrackActualCola) _senializarTrackTerminado(stateKey);
      _decryptClienteSaltado.add(rawId);
      _fallosDecryptCount.remove(rawId);
      final altFinal = await _buscarArchivoAlternativo(stateKey, playablePath);
      if (altFinal != null) {
        _log.i('[poll] decrypt falló para $rawId pero existe alternativa: $altFinal — manteniendo completado');
        _completadosPersistidos.add(rawId);
        try {
          final meta = _metaTrack[stateKey];
          final nid = meta != null && meta.trackId.isNotEmpty ? meta.trackId : stateKey;
          await _downloadCache.actualizarRutaArchivo(nid, altFinal);
        } catch (_) {}
        return (rutaReproducible: altFinal, continuar: true);
      }
      // No marcar interrumpido si la cola FIFO espera este track — la nueva
      // descarga sigue en progreso.
      if (stateKey == _idTrackActualCola) {
        _log.i('[poll] $rawId: decrypt falló pero la cola está activa — manteniendo enProgreso');
        dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.enProgreso, progreso: 0.95);
      } else {
        dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido, progreso: 0.0);
        // Solo mostrar el snackbar feo cuando la cola NO está activa para este
        // track. Con cola activa, el track puede completar vía otro proveedor.
        _errorDesencriptadoPendiente = 'decrypt';
      }
      return (rutaReproducible: null, continuar: false);
    }
    _decryptClienteHecho.add(rawId);
    _fallosDecryptCount.remove(rawId);
    return (rutaReproducible: decrypted, continuar: true);
  }
}