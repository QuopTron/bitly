// ─────────────────────────────────────────────────────────────
// descargas_inicio_album.dart — PART de cubit_descargas.dart:
// inicio de la descarga de un ÁLBUM completo: cada track uno por uno
// con los ajustes del usuario. Dedup por ID ya descargado y por ISRC
// dentro del mismo lote (tracks bonus de ediciones múltiples),
// registra el lote en _batchTrackIds/_datosLote y lo persiste como
// in_progress para que sobreviva un reinicio.
// Se conecta con: descargas_inicio.dart (misma library).
// Parte del flujo: descargas (botón de descarga de álbum).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Inicio de descarga de álbumes. Mixin aplicado en CubitDescargas.
mixin DescargasInicioAlbum on DescargasInicio {
  /// Inicia la descarga de un álbum — cada track uno por uno con ajustes.
  /// [tracks] debe ser una lista de maps con: track_id, track_title,
  /// artist_name, album_name, source, isrc, duration_ms. [source] es la
  /// fuente (p.ej. "spotify") usada para construir la key de lote que el grid
  /// consulta para el progreso agregado.
  void iniciarDescargaAlbum(
    String albumId,
    List<Map<String, dynamic>> tracks, {
    AjustesDescarga? ajustes,
    String source = '',
    String? calidadForzada,
  }) async {
    final batchKey = 'album_${normalizarId(albumId)}_$source';
    if (state.descargas[batchKey]?.estado == EstadoDescarga.enProgreso) return;
    if (tracks.isEmpty) return;
    if (!await _verificarCarpetaDescargas()) return;
    if (!await _verificarSesionesAntesDeDescargar()) return;

    final s = ajustes ?? const AjustesDescarga();
    final audioIds = <String>[];
    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    final seenIsrcs = <String>{}; // Dedup por ISRC dentro del lote.

    for (final t in tracks) {
      final tid = (t['track_id'] as String?) ?? '';
      if (tid.isEmpty) continue;
      final normalizedTid = normalizarId(tid);
      final baseId = 'track_${normalizedTid}_$source';
      audioIds.add(baseId);

      final yaHecho = _idsTracksDescargados.contains(normalizedTid)
          || state.descargas[baseId]?.estado == EstadoDescarga.completado;
      if (yaHecho) {
        _asegurarMetaTrack(baseId, normalizedTid, t, source);
        dl[baseId] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
        continue;
      }
      // Dedup por ISRC en el mismo lote (tracks bonus de ediciones múltiples).
      final isrc = (t['isrc'] ?? '').toString();
      if (isrc.isNotEmpty && !seenIsrcs.add(isrc)) {
        _log.i('[iniciarDescargaAlbum] skip ISRC duplicado en lote: $isrc');
        dl[baseId] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
        continue;
      }
      dl[baseId] = const DatosEstadoDescarga(estado: EstadoDescarga.enCola, progreso: 0.0);
      _colaDescargas.add(_TrackEnCola(t, tid, source, s, calidadForzada, batchKey));
    }

    if (audioIds.isEmpty) return;
    _batchTrackIds[batchKey] = audioIds;
    _datosLote[batchKey] = _DatosLote(tracks, s, source, calidadForzada);
    _asegurarPolling();

    dl[batchKey] = const DatosEstadoDescarga(estado: EstadoDescarga.enProgreso, progreso: 0.0);
    emit(state.copiarCon(descargas: dl));

    // Persistir el lote como in_progress para que sobreviva un reinicio.
    final batchName = (tracks.isNotEmpty) ? (tracks.first['album_name'] as String? ?? '') : '';
    final albumMeta = tracks.map((t) => <String, dynamic>{
      'name': (t['track_title'] ?? '') as String,
      'artist': (t['artist_name'] ?? '') as String,
      'cover': (t['cover_url'] ?? '') as String,
    }).toList();
    await _downloadCache.guardarLoteDescargado(
      batchKey, 'album', albumId, source, batchName,
      trackIds: audioIds,
      trackMeta: albumMeta,
    );

    _procesarColaDescargas();
  }
}