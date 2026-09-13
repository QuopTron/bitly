// ─────────────────────────────────────────────────────────────
// descargas_borrar_lote.dart — PART de cubit_descargas.dart:
// borrado de un lote completo que aún vive en memoria (_datosLote).
// Calcula stems de archivos (audio, letras lyrics_{sha1}, video
// "artista - título"), chequea conteos de referencia ANTES de borrar
// del disco (solo cuando ningún otro lote o like usa el archivo),
// quita carátulas solo si el padre ya no está amado, borra filas de
// BD, cancela trackers de Go y limpia el estado.
// Se conecta con: descargas_borrar_playlist.dart (misma library).
// Parte del flujo: descargas (borrado de álbum/playlist).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Borrado de un lote en memoria. Mixin aplicado en CubitDescargas.
mixin DescargasBorrarLote on DescargasBorrarPlaylist {
  @override
  Future<void> _borrarLote(String batchKey) async {
    final data = _datosLote[batchKey];
    if (data == null) return;

    final allIdsToDelete = <String>{};
    final audioIdsInBatch = <String>[];
    final fileStems = <String>{};
    final coversToDelete = <String>{};
    for (final t in data.tracks) {
      final originalId = (t['track_id'] as String?) ?? '';
      if (originalId.isEmpty) continue;
      final normalizedId = normalizarId(originalId);
      allIdsToDelete.add(originalId);
      allIdsToDelete.add(normalizedId);
      audioIdsInBatch.add('track_${normalizedId}_${data.source}');
      fileStems.addAll({originalId, normalizedId});
      // lyrics_{sha1(TrackID)} — probar original y normalizado.
      for (final id in {originalId, normalizedId}) {
        if (id.isNotEmpty) fileStems.add('lyrics_${_sha1Hex(id)}');
      }
      // video: {artistaSanitizado} - {tituloSanitizado}.mp4
      final title = (t['track_title'] as String?) ?? '';
      final artist = (t['artist_name'] as String?) ?? '';
      if (title.isNotEmpty && artist.isNotEmpty) {
        fileStems.add('${_sanitizarNombreArchivo(artist)} - ${_sanitizarNombreArchivo(title)}');
      }
      final coverUrl = (t['cover_url'] as String?) ?? '';
      if (coverUrl.isNotEmpty) {
        final likeCubit = di.sl<CubitLikes>();
        final esAmado = [originalId, normalizedId]
            .any((id) => id.isNotEmpty && likeCubit.estaItemIdAmado(id));
        if (!esAmado) coversToDelete.add(coverUrl);
      }
    }
    if (allIdsToDelete.isEmpty) return;

    // Carátulas: borrar cada URL una sola vez y solo si el álbum/playlist
    // padre ya no está amado (el like muestra la misma portada).
    if (coversToDelete.isNotEmpty && !_padreAmado(batchKey)) {
      for (final coverUrl in coversToDelete) {
        try { await _backend.deleteCover(coverUrl); } catch (_) {}
      }
    }

    // Chequear conteos de referencia ANTES de borrar: solo quitar archivos
    // del disco cuando ningún otro lote (álbum/playlist) o like los referencia.
    final stemsToDelete = <String>{};
    for (final t in data.tracks) {
      final originalId = (t['track_id'] as String?) ?? '';
      if (originalId.isEmpty) continue;
      final normalizedId = normalizarId(originalId);
      final likeCubit = di.sl<CubitLikes>();
      final esAmado = [originalId, normalizedId]
          .any((id) => id.isNotEmpty && likeCubit.estaItemIdAmado(id));
      // batchCount incluye este lote (aún no removido de la BD), >1 = compartido.
      final batchCount = await _downloadCache.contarLotesReferenciandoTrack(normalizedId);
      if (!esAmado && batchCount <= 1) {
        stemsToDelete.addAll({originalId, normalizedId});
        for (final id in {originalId, normalizedId}) {
          if (id.isNotEmpty) stemsToDelete.add('lyrics_${_sha1Hex(id)}');
        }
        final title = (t['track_title'] as String?) ?? '';
        final artist = (t['artist_name'] as String?) ?? '';
        if (title.isNotEmpty && artist.isNotEmpty) {
          stemsToDelete.add('${_sanitizarNombreArchivo(artist)} - ${_sanitizarNombreArchivo(title)}');
        }
      }
    }

    await _downloadCache.borrarTracksDescargados(allIdsToDelete.toList());
    await _downloadCache.quitarLotes([batchKey]);

    // Quitar referencias del player para TODOS los tracks; borrar archivos
    // solo para tracks que ningún otro lote/like referencia.
    di.sl<CubitReproductor>().eliminarArchivosLocalesPorProveedores(fileStems.toList(), borrarArchivos: false);
    if (stemsToDelete.isNotEmpty) {
      di.sl<CubitReproductor>().eliminarArchivosLocalesPorProveedores(stemsToDelete.toList(), borrarArchivos: true);
    }
    di.sl<CacheBiblioteca>().invalidarTodo();

    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    final fps = Set<String>.from(state.huellasDescargadas);
    dl.remove(batchKey);
    final trackerIds = <String>[];
    for (final audioId in audioIdsInBatch) {
      dl.remove(audioId);
      final meta = _metaTrack[audioId];
      if (meta != null) {
        final fpName = meta.name.isNotEmpty ? meta.name : normalizarId(meta.trackId);
        final fpArtist = meta.artist ?? '';
        fps.remove(huellaDesdeNombre(fpName, fpArtist));
      }
      _metaTrack.remove(audioId);
      // Limpiar la caché para que iniciarDescargaAlbum ya no salte este track.
      final parts = audioId.split('_');
      if (parts.length >= 3) {
        final normId = parts.sublist(1, parts.length - 1).join('_');
        _idsTracksDescargados.remove(normId);
      }
      trackerIds.addAll(_itemIdAKeyEstado.entries
          .where((e) => e.value == audioId)
          .map((e) => e.key));
      _itemIdAKeyEstado.removeWhere((k, v) => v == audioId);
      // Limpiar state keys de video y letra.
      dl.remove('${audioId}_video');
      dl.remove('${audioId}_lyrics');
      trackerIds.addAll(_itemIdAKeyEstado.entries
          .where((e) => e.value == '${audioId}_video' || e.value == '${audioId}_lyrics')
          .map((e) => e.key));
      _itemIdAKeyEstado.removeWhere((k, v) =>
          v == '${audioId}_video' || v == '${audioId}_lyrics');
    }
    // Olvidar la persistencia y sacar la entrada del tracker de Go para que el
    // próximo poll no resucite la descarga borrada.
    _borradosPendientes.addAll(trackerIds);
    for (final tid in trackerIds) {
      unawaited(_backend.cancelDownload(tid));
    }
    _datosLote.remove(batchKey);
    _batchTrackIds.remove(batchKey);
    _reintentosAutoPorLote.remove(batchKey);
    _reintentosFallidosPorLote.remove(batchKey);
    emit(state.copiarCon(descargas: dl, huellasDescargadas: fps));
  }
}