// ─────────────────────────────────────────────────────────────
// descargas_carga_lotes_caratulas.dart — PART de cubit_descargas
// .dart: backfill de carátulas de lotes restaurados — un track sin
// carátula adoptar la del álbum/playlist amado que lo contiene y un
// lote sin carátula adoptar la del primer track que sí tenga una.
// Se conecta con: descargas_carga_lotes.dart (misma library).
// Parte del flujo: descargas (carga del historial).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

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
      final albumAmado = cubitLikes.state.todosAmados.values
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
      _metaTrack[entry.key] = _InfoTrack(
        meta.trackId,
        meta.name,
        meta.artist,
        coverAlbum,
        meta.source,
        meta.coverPath,
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
      final cover = (meta.coverPath?.isNotEmpty ?? false)
          ? meta.coverPath!
          : (meta.coverUrl ?? '');
      if (cover.isNotEmpty) {
        _metaLote[batchKey] = _MetaLote(
          bm.name,
          bm.itemType,
          bm.itemId,
          bm.source,
          coverUrl: bm.coverUrl.isNotEmpty ? bm.coverUrl : cover,
          coverPath: bm.coverPath.isNotEmpty ? bm.coverPath : cover,
        );
        cambiado = true;
      }
      vistos.add(batchKey);
    }
    return cambiado;
  }
}
