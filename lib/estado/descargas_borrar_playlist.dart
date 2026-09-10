// ─────────────────────────────────────────────────────────────
// descargas_borrar_playlist.dart — PART de cubit_descargas.dart:
// borrado de la descarga de una PLAYLIST: remueve archivos del disco
// (cuando ya no se usan), filas de la BD, carátulas (solo si la
// playlist ya no está amada), fingerprints y estado en memoria, y
// pide a Go cancelar los trackers para que el poll no resucite la
// descarga borrada. Es el espejo de descargas_borrar.dart pero para
// playlists.
// Se conecta con: descargas_borrar.dart (misma library).
// Parte del flujo: descargas (borrar playlist de Mi Espacio).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Borrado de descargas de playlist. Mixin aplicado en CubitDescargas.
mixin DescargasBorrarPlaylist on DescargasBorrar {
  /// Borra todos los tracks descargados de un lote de playlist.
  Future<void> borrarDescargaPlaylist(String playlistId, String source) async {
    final batchKey = 'playlist_${normalizarId(playlistId)}_$source';
    final data = _datosLote[batchKey];
    if (data != null) {
      await _borrarLote(batchKey);
      return;
    }
    // Tras reinicio: obtener los track IDs desde la entrada del lote.
    var batch = await _downloadCache.getLotePorItem('playlist', playlistId, source);
    var sourceEfectiva = source;
    if (batch == null && source.isNotEmpty) {
      batch = await _downloadCache.getLotePorItem('playlist', playlistId, '');
      if (batch != null) sourceEfectiva = '';
    }
    final stateKeys = <String>[];
    if (batch?.trackIds != null && batch!.trackIds!.isNotEmpty) {
      final decoded = jsonDecode(batch.trackIds!) as List<dynamic>;
      for (final entry in decoded) {
        if (entry is String) {
          stateKeys.add(entry);
        } else if (entry is Map<String, dynamic>) {
          final id = (entry['id'] ?? '') as String;
          if (id.isNotEmpty) stateKeys.add(id);
        }
      }
    }
    if (stateKeys.isNotEmpty) {
      final allIds = <String>{};
      final fileStems = <String>{};
      final coversToDelete = <String>{};
      for (final stateKey in stateKeys) {
        allIds.add(stateKey);
        final parts = stateKey.split('_');
        if (parts.length >= 3) {
          final extractedId = parts.sublist(1, parts.length - 1).join('_');
          allIds.add(extractedId);
          fileStems.add(extractedId);
          fileStems.add('lyrics_${_sha1Hex(extractedId)}');
          final meta = _metaTrack[stateKey];
          if (meta != null) {
            fileStems.add('lyrics_${_sha1Hex(meta.trackId)}');
            if (meta.name.isNotEmpty && meta.artist != null && meta.artist!.isNotEmpty) {
              fileStems.add('${_sanitizarNombreArchivo(meta.artist!)} - ${_sanitizarNombreArchivo(meta.name)}');
            }
            if (meta.coverUrl != null && meta.coverUrl!.isNotEmpty) {
              coversToDelete.add(meta.coverUrl!);
            }
          }
          _idsTracksDescargados.remove(extractedId);
        }
      }
      // Carátulas: borrar cada URL una sola vez y solo si la playlist ya no
      // está amada (el like muestra la misma portada en Mi Espacio).
      if (coversToDelete.isNotEmpty && !_padreAmado(batchKey)) {
        for (final coverUrl in coversToDelete) {
          try { await _backend.deleteCover(coverUrl); } catch (_) {}
        }
      }
      await _downloadCache.borrarTracksDescargados(allIds.toList());
      di.sl<CubitReproductor>().eliminarArchivosLocalesPorProveedores(fileStems.toList(), borrarArchivos: true);
    }
    await _downloadCache.quitarLotePorItem('playlist', playlistId, sourceEfectiva);
    di.sl<CacheBiblioteca>().invalidarTodo();
    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    final fps = Set<String>.from(state.huellasDescargadas);
    dl.remove(batchKey);
    // Quitar los tracks individuales del estado.
    final trackerIds = <String>[];
    for (final stateKey in stateKeys) {
      dl.remove(stateKey);
      final meta = _metaTrack[stateKey];
      if (meta != null) {
        final fpName = meta.name.isNotEmpty ? meta.name : normalizarId(meta.trackId);
        final fpArtist = meta.artist ?? '';
        fps.remove(huellaDesdeNombre(fpName, fpArtist));
      }
      _metaTrack.remove(stateKey);
      final parts = stateKey.split('_');
      if (parts.length >= 3) {
        final normId = parts.sublist(1, parts.length - 1).join('_');
        _idsTracksDescargados.remove(normId);
      }
      trackerIds.addAll(_itemIdAKeyEstado.entries
          .where((e) => e.value == stateKey)
          .map((e) => e.key));
      _itemIdAKeyEstado.removeWhere((k, v) => v == stateKey);
      dl.remove('${stateKey}_video');
      dl.remove('${stateKey}_lyrics');
      _itemIdAKeyEstado.removeWhere((k, v) =>
          v == '${stateKey}_video' || v == '${stateKey}_lyrics');
    }
    _borradosPendientes.addAll(trackerIds);
    for (final tid in trackerIds) {
      unawaited(_backend.cancelDownload(tid));
    }
    emit(state.copiarCon(descargas: dl, huellasDescargadas: fps));
  }
}