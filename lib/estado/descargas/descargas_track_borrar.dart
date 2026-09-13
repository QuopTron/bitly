// ─────────────────────────────────────────────────────────────
// descargas_track_borrar.dart — PART de cubit_descargas.dart:
// borrado de la descarga de UN track: prueba múltiples formatos de
// ID (guardado, normalizado, original) para hallar la fila de BD,
// respeta otros consumidores (otros lotes o el like conservan el
// archivo en disco), borra carátula solo si no está amado, cancela
// los trackers de Go (incluidos video/letra) y actualiza el estado
// del lote padre según el nuevo conteo de tracks completados.
// Se conecta con: descargas_despacho.dart (misma library).
// Parte del flujo: descargas (borrar track de Mi Espacio).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Borrado de tracks individuales. Mixin aplicado en CubitDescargas.
mixin DescargasTrackBorrar on DescargasDespacho {
  /// Actualiza el estado del lote padre tras borrar un track — implementación
  /// concreta en DescargasTrackBatch (arriba en la cadena).
  Future<void> _actualizarEstadoLoteTrasBorrar(
      String normalizedId, Map<String, DatosEstadoDescarga> dl);

  /// Borra un track descargado por su ID y fuente. Usa múltiples formatos de
  /// ID (almacenado, normalizado y original) para asegurar el hallazgo de la
  /// fila en BD sin importar cómo se guardó.
  Future<void> borrarDescargaTrack(String trackId, String source) async {
    final normalizedId = normalizarId(trackId);
    final audioId = 'track_${normalizedId}_$source';

    final meta = _metaTrack[audioId];
    final idsAProbar = <String>{};
    if (meta != null && meta.trackId.isNotEmpty) idsAProbar.add(meta.trackId);
    idsAProbar.add(normalizedId);
    if (trackId.isNotEmpty) idsAProbar.add(trackId);
    // Si OTRO lote (álbum/playlist) o un item amado aún referencia este track,
    // solo quitar la fila de BD — mantener el archivo en disco para el otro.
    bool otroConsumidorExiste = false;
    for (final id in idsAProbar) {
      if (id.isEmpty) continue;
      final batchCount = await _downloadCache.contarLotesReferenciandoTrack(id);
      if (batchCount > 1) { otroConsumidorExiste = true; break; }
    }
    final likeCubit = di.sl<CubitLikes>();
    final esAmado = [meta?.trackId ?? '', trackId, normalizedId]
        .any((id) => id.isNotEmpty && likeCubit.estaItemIdAmado(id));
    if (esAmado) otroConsumidorExiste = true;

    await _downloadCache.borrarTracksDescargados(idsAProbar.toList());

    // Stems de archivos para limpieza de disco: audio + letras + video.
    final fileStems = <String>{...idsAProbar};
    for (final id in {trackId, normalizedId, meta?.trackId ?? ''}) {
      if (id.isNotEmpty) fileStems.add('lyrics_${_sha1Hex(id)}');
    }
    if (meta != null && meta.name.isNotEmpty && meta.artist != null && meta.artist!.isNotEmpty) {
      fileStems.add('${_sanitizarNombreArchivo(meta.artist!)} - ${_sanitizarNombreArchivo(meta.name)}');
    }
    // Borrar archivos del disco solo cuando NINGÚN otro lote/like los usa.
    di.sl<CubitReproductor>().eliminarArchivosLocalesPorProveedores(fileStems.toList(), borrarArchivos: !otroConsumidorExiste);
    di.sl<CacheBiblioteca>().invalidarTodo();

    // Limpiar la carátula solo si el track NO está también amado (el flujo de
    // unlike hace lo mismo).
    if (meta?.coverUrl != null && meta!.coverUrl!.isNotEmpty) {
      final esAmado = [meta.trackId, trackId, normalizedId]
          .any((id) => id.isNotEmpty && likeCubit.estaItemIdAmado(id));
      if (!esAmado) {
        try { await _backend.deleteCover(meta.coverUrl!); } catch (_) {}
      }
    }

    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    final fps = Set<String>.from(state.huellasDescargadas);
    dl.remove(audioId);
    _metaTrack.remove(audioId);

    // Limpiar state keys de video y letra.
    final videoKey = '${audioId}_video';
    final lyricsKey = '${audioId}_lyrics';
    dl.remove(videoKey);
    dl.remove(lyricsKey);

    // Limpiar el mapeo de item IDs del backend y pedirle a Go que deje de
    // reportar la entrada: si no, el próximo poll la volvería a guardar
    // (resurrección fantasma de la descarga borrada).
    final trackerIds = _itemIdAKeyEstado.entries
        .where((e) =>
            e.value == audioId || e.value == videoKey || e.value == lyricsKey)
        .map((e) => e.key)
        .toList();
    _itemIdAKeyEstado.removeWhere((k, v) => trackerIds.contains(k));
    _borradosPendientes.addAll(trackerIds);
    for (final tid in trackerIds) {
      unawaited(_backend.cancelDownload(tid));
    }

    // Limpiar fingerprints para que el track no reaparezca.
    if (meta != null) {
      final fpName = meta.name.isNotEmpty ? meta.name : normalizedId;
      final fpArtist = meta.artist ?? '';
      fps.remove(huellaDesdeNombre(fpName, fpArtist));
    }

    // Si el track pertenece a un lote, actualizar el estado del lote según el
    // nuevo conteo de tracks completados (implementado en DescargasTrackBatch).
    await _actualizarEstadoLoteTrasBorrar(normalizedId, dl);

    emit(state.copiarCon(descargas: dl, huellasDescargadas: fps));
  }

  /// Borra un track descargado aunque la card se haya mostrado desde una
  /// extensión DISTINTA a la que realmente lo descargó. Si la entrada exacta
  /// por fuente no es la descarga, resuelve la entrada real por fingerprint
  /// (agnóstico de fuente, igual que el like) y borra esa.
  Future<void> borrarTrackResuelto(ItemFeed item) async {
    final baseId = 'track_${normalizarId(item.id)}_${item.source ?? ''}';
    final tengoExacta = _metaTrack.containsKey(baseId) ||
        state.descargas[baseId]?.estado == EstadoDescarga.completado;
    if (tengoExacta) {
      await borrarDescargaTrack(item.id, item.source ?? '');
      return;
    }
    final targetFp = huellaDesdeNombre(item.name, item.artists ?? '');
    _InfoTrack? match;
    for (final meta in _metaTrack.values) {
      if (huellaDesdeNombre(meta.name, meta.artist ?? '') == targetFp) {
        match = meta;
        break;
      }
    }
    if (match != null) {
      await borrarDescargaTrack(match.trackId, match.source);
    }
  }
}