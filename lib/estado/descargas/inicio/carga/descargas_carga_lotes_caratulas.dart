// ─────────────────────────────────────────────────────────────
// descargas_carga_lotes_caratulas.dart — PART de cubit_descargas
// .dart: backfill de carátulas de lotes restaurados — un track sin
// carátula adoptar la del álbum/playlist amado que lo contiene y un
// lote sin carátula adoptar la del primer track que sí tenga una.
// Se conecta con: descargas_carga_lotes.dart (misma library).
// Parte del flujo: descargas (carga del historial).
// ─────────────────────────────────────────────────────────────

part of '../../cubit_descargas.dart';

/// Backfill de carátulas de los lotes restaurados. Devuelve true si
/// cambió algo (la carga lo usa para emitir estado nuevo).
mixin DescargasCargaLotesCaratulas on DescargasCargaTracks {
  /// [mapaTrackALote] relaciona el id normalizado de cada track con su lote.
  Future<bool> _backfillCaratulasDeLotes(
    Map<String, String> mapaTrackALote,
  ) async {
    if (mapaTrackALote.isEmpty) return false;
    var cambiado = false;

    // ── 3. Tracks sin carátula adoptan la del álbum/playlist amado ──
    final cubitLikes = di.sl<CubitLikes>();
    for (final entry in _metaTrack.entries) {
      final meta = entry.value;
      if (meta.coverUrl?.isNotEmpty ?? false) continue;
      if (meta.coverPath?.isNotEmpty ?? false) continue;
      final batchKey = mapaTrackALote[meta.trackId];
      if (batchKey == null) continue;
      final bm = _metaLote[batchKey];
      if (bm == null) continue;
      final albumAmado =
          cubitLikes.state.todosAmados.values
              .where(
                (i) =>
                    i.type == bm.itemType &&
                    normalizarId(i.id) == normalizarId(bm.itemId),
              )
              .firstOrNull;
      final coverAlbum =
          albumAmado?.rutaCaratulaLocal?.isNotEmpty == true
              ? albumAmado!.rutaCaratulaLocal
              : albumAmado?.coverUrl;
      if (coverAlbum == null || coverAlbum.isEmpty) continue;
      // La carátula del álbum amado puede ser una ruta local o una URL: cada
      // una va a su campo, y la fila se persiste para no rehacerlo al volver.
      final esLocal =
          coverAlbum.startsWith('/') ||
          (coverAlbum.length > 3 && coverAlbum[1] == ':');
      _metaTrack[entry.key] = _InfoTrack(
        meta.trackId,
        meta.name,
        meta.artist,
        esLocal ? meta.coverUrl : coverAlbum,
        meta.source,
        esLocal ? coverAlbum : meta.coverPath,
      );
      await _downloadCache.actualizarCaratulaTrack(
        meta.trackId,
        esLocal ? '' : coverAlbum,
        esLocal ? coverAlbum : '',
      );
      cambiado = true;
    }

    // ── 3b. Lotes sin carátula adoptan la del primer track con una ──
    final vistos = <String>{};
    for (final entry in _metaTrack.entries) {
      final meta = entry.value;
      final batchKey = mapaTrackALote[meta.trackId];
      if (batchKey == null || vistos.contains(batchKey)) continue;
      final bm = _metaLote[batchKey];
      if (bm == null || bm.coverUrl.isNotEmpty) {
        vistos.add(batchKey);
        continue;
      }
      // La ruta local y la URL son campos distintos: guardar una URL en
      // coverPath hacía que la UI la tratara como archivo en disco.
      final rutaLocal =
          (meta.coverPath?.isNotEmpty ?? false) ? meta.coverPath! : '';
      final url = meta.coverUrl?.isNotEmpty == true ? meta.coverUrl! : '';
      if (rutaLocal.isNotEmpty || url.isNotEmpty) {
        final nuevoUrl = bm.coverUrl.isNotEmpty ? bm.coverUrl : url;
        final nuevoPath = bm.coverPath.isNotEmpty ? bm.coverPath : rutaLocal;
        _metaLote[batchKey] = _MetaLote(
          bm.name,
          bm.itemType,
          bm.itemId,
          bm.source,
          coverUrl: nuevoUrl,
          coverPath: nuevoPath,
        );
        // Persistir: sin esto el lote volvía a quedar gris en el arranque.
        await _downloadCache.actualizarCaratulaLote(
          batchKey,
          nuevoUrl,
          nuevoPath,
        );
        cambiado = true;
      }
      vistos.add(batchKey);
    }
    return cambiado;
  }

  /// Lotes sin nombre o sin carátula que adoptan las de la BIBLIOTECA LOCAL.
  ///
  /// Por qué: el nombre del lote se escribe al EMPEZAR la descarga (cuando el
  /// álbum todavía puede venir sin nombre) y la carátula recién al terminar.
  /// Un lote parcial —o uno cuyo guardado de portada falló— quedaba sin nada,
  /// y la tarjeta gris era permanente aunque la tabla `albums` tuviera el
  /// nombre y la URL de portada del mismo álbum.
  Future<bool> _backfillLotesDesdeBiblioteca() async {
    var cambiado = false;
    for (final entry in _metaLote.entries) {
      final bm = entry.value;
      final yaTieneCover = bm.coverUrl.isNotEmpty || bm.coverPath.isNotEmpty;
      if (bm.name.isNotEmpty && yaTieneCover) continue;
      if (bm.itemType != 'album') continue;
      var nombre = bm.name;
      var url = bm.coverUrl;
      var ruta = bm.coverPath;
      final album = await _contentLote.getAlbumPorIdNormalizado(bm.itemId);
      if (album != null) {
        if (nombre.isEmpty) nombre = album.name;
        if (mejorCaratula(ruta, url) == null) {
          url = album.coverUrl ?? '';
          ruta = album.coverPath ?? '';
        }
      }
      if (nombre.isEmpty && url.isEmpty && ruta.isEmpty) continue;
      _metaLote[entry.key] = _MetaLote(
        nombre,
        bm.itemType,
        bm.itemId,
        bm.source,
        coverUrl: url,
        coverPath: ruta,
      );
      await _downloadCache.actualizarCaratulaLote(entry.key, url, ruta);
      cambiado = true;
    }
    return cambiado;
  }
}
