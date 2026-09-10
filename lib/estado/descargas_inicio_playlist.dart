// ─────────────────────────────────────────────────────────────
// descargas_inicio_playlist.dart — PART de cubit_descargas.dart:
// inicio de la descarga de una PLAYLIST completa: cada track uno por
// uno con los ajustes del usuario. Dedup por ID ya descargado y por
// ISRC dentro del mismo lote (tracks duplicados entre playlists),
// registra el lote en _batchTrackIds/_datosLote y lo persiste como
// in_progress para que sobreviva un reinicio.
// Se conecta con: descargas_inicio_album.dart (misma library).
// Parte del flujo: descargas (botón de descarga de playlist).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Inicio de descarga de playlists. Mixin aplicado en CubitDescargas.
mixin DescargasInicioPlaylist on DescargasInicioAlbum {
  /// Inicia la descarga de una playlist — cada track uno por uno con ajustes.
  void iniciarDescargaPlaylist(
    String playlistId,
    List<Map<String, dynamic>> tracks, {
    AjustesDescarga? ajustes,
    String source = '',
    String? calidadForzada,
  }) async {
    final batchKey = 'playlist_${normalizarId(playlistId)}_$source';
    if (state.descargas[batchKey]?.estado == EstadoDescarga.enProgreso) return;
    if (tracks.isEmpty) return;
    if (!await _verificarCarpetaDescargas()) return;
    if (!await _verificarSesionesAntesDeDescargar()) return;

    final s = ajustes ?? const AjustesDescarga();
    final audioIds = <String>[];
    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    final seenIsrcs = <String>{}; // Dedup por ISRC dentro del lote.

    _log.i('[iniciarDescargaPlaylist] batchKey=$batchKey tracks=${tracks.length} source=$source');

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
      // Dedup por ISRC en el mismo lote (tracks duplicados entre playlists).
      final isrc = (t['isrc'] ?? '').toString();
      if (isrc.isNotEmpty && !seenIsrcs.add(isrc)) {
        _log.i('[iniciarDescargaPlaylist] skip ISRC duplicado en lote: $isrc');
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
    final playlistMeta = tracks.map((t) => <String, dynamic>{
      'name': (t['track_title'] ?? '') as String,
      'artist': (t['artist_name'] ?? '') as String,
      'cover': (t['cover_url'] ?? '') as String,
    }).toList();
    await _downloadCache.guardarLoteDescargado(
      batchKey, 'playlist', playlistId, source, batchName,
      trackIds: audioIds,
      trackMeta: playlistMeta,
    );

    _procesarColaDescargas();
  }
}