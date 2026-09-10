// ─────────────────────────────────────────────────────────────
// descargas_cola_verificar.dart — PART de cubit_descargas.dart:
// verificación post-descarga (¿el track completado tiene un archivo
// reproducible en disco? buscando alternativas cuando la ruta
// guardada está rota), cancelación de trackers huérfanos de Go
// (evita resurrección fantasma), señalización de fin de track a la
// cola secuencial, encolado de un track único (lote de singles) y
// resolución de la ruta local de un track descargado.
// Se conecta con: descargas_carga.dart (misma library).
// Parte del flujo: descargas (cola secuencial y borrado).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Verificación y helpers de la cola. Mixin aplicado en CubitDescargas.
mixin DescargasColaVerificar on DescargasCarga {
  /// Procesa la cola global de descargas — implementación concreta en
  /// DescargasCola (arriba en la cadena).
  Future<void> _procesarColaDescargas();

  /// Verifica que un track completado realmente tenga un archivo reproducible
  /// en disco. Devuelve false si el archivo falta, es muy chico o no empieza
  /// con magic bytes de audio válidos. También busca archivos alternativos
  /// reproducibles cuando la ruta guardada está rota (carrera de proveedores).
  Future<bool> _verificarArchivoDescargado(String baseId) async {
    final meta = _metaTrack[baseId];
    if (meta == null) return false;
    final filePath = await _downloadCache.getRutaArchivoPorId(meta.trackId);
    if (filePath == null || filePath.isEmpty) {
      // Probar el ID normalizado como fallback.
      final altPath = await _downloadCache.getRutaArchivoPorId(baseId);
      if (altPath != null && altPath.isNotEmpty) {
        if (await _esAudioDecodificable(File(altPath))) return true;
        // Archivo de la BD no reproducible — buscar alternativa en disco.
        final diskAlt = await _buscarArchivoAlternativo(baseId, altPath);
        if (diskAlt != null) {
          _log.i('[verificar] alternativa encontrada para $baseId: $diskAlt');
          try {
            final nid = meta.trackId.isNotEmpty ? meta.trackId : baseId;
            await _downloadCache.guardarTrackDescargado(
              id: nid, trackName: meta.name, artistName: meta.artist ?? '',
              filePath: diskAlt, service: meta.source,
            );
          } catch (_) {}
          return true;
        }
      }
      // Sin fila en BD — buscar en disco directo (Apple Music .m4a o
      // SoundCloud .mp3 pueden existir aunque el poll nunca actualizó la BD).
      final diskAlt = await _buscarArchivoAlternativo(baseId);
      if (diskAlt != null) {
        _log.i('[verificar] sin fila en BD pero encontrado en disco: $diskAlt para $baseId');
        try {
          final nid = meta.trackId.isNotEmpty ? meta.trackId : baseId;
          await _downloadCache.guardarTrackDescargado(
            id: nid, trackName: meta.name, artistName: meta.artist ?? '',
            filePath: diskAlt, service: meta.source,
          );
        } catch (_) {}
        return true;
      }
      return false;
    }
    if (await _esAudioDecodificable(File(filePath))) return true;
    // El archivo existe pero no es reproducible — buscar alternativa.
    final diskAlt = await _buscarArchivoAlternativo(baseId, filePath);
    if (diskAlt != null) {
      _log.i('[verificar] alternativa encontrada para $baseId: $diskAlt');
      try {
        final nid = meta.trackId.isNotEmpty ? meta.trackId : baseId;
        await _downloadCache.actualizarRutaArchivo(nid, diskAlt);
      } catch (_) {}
      return true;
    }
    return false;
  }

  /// Señala a la cola que el track actual terminó (completó o se abandonó).
  void _senializarTrackTerminado(String stateKey) {
    if (_completadorTrackActual != null &&
        !_completadorTrackActual!.isCompleted &&
        stateKey == _idTrackActualCola) {
      _completadorTrackActual!.complete();
    }
  }

  /// Encola un track único. Usa la cola global para respetar el orden de los
  /// lotes (no descarga en paralelo con álbumes/playlists en curso).
  void encolarTrackIndividual({
    required Map<String, dynamic> metaComun,
    required AjustesDescarga ajustes,
    required String baseId,
    String? calidadForzada,
  }) {
    final itemId = metaComun['item_id'] as String? ?? metaComun['track_id'] as String? ?? '';
    final source = metaComun['source'] as String? ?? '';

    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    dl[baseId] = const DatosEstadoDescarga(estado: EstadoDescarga.enCola, progreso: 0.0);
    emit(state.copiarCon(descargas: dl));

    _colaDescargas.add(_TrackEnCola(metaComun, itemId, source, ajustes, calidadForzada, '_singles'));
    _procesarColaDescargas();
  }

  /// Devuelve la ruta local de un track descargado, o null si no existe.
  Future<String?> obtenerRutaTrack(String trackId, String source) async {
    final normalizedId = normalizarId(trackId);
    final audioId = 'track_${normalizedId}_$source';
    final meta = _metaTrack[audioId];
    final idsAProbar = <String>{};
    if (meta != null && meta.trackId.isNotEmpty) idsAProbar.add(meta.trackId);
    idsAProbar.add(normalizedId);
    if (trackId.isNotEmpty) idsAProbar.add(trackId);
    for (final id in idsAProbar) {
      final ruta = await _downloadCache.getRutaArchivoPorId(id);
      if (ruta != null && ruta.isNotEmpty) return ruta;
    }
    return null;
  }
}