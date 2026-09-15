// ---------------------------------------------------------------------------
// download_dao_lotes.dart — PART de download_dao.dart: mixin con las
// operaciones sobre LOTES de descarga (álbum/playlist completos) —
// alta, consulta, borrado y el conteo de lotes que referencian un
// track (para borrar el audio solo cuando ningún otro lote lo usa).
// Se conecta con: download_dao.dart (misma library, incluido el mixin
// generado `_$DownloadDaoMixin`).
// Parte del flujo: descargas (lotes por álbum/playlist).
// ---------------------------------------------------------------------------

part of 'download_dao.dart';

mixin _DownloadDaoLotes on DatabaseAccessor<AppDatabase>, _$DownloadDaoMixin {
  Future<void> saveBatch(DownloadBatchesCompanion entry) =>
      into(downloadBatches).insertOnConflictUpdate(entry);

  Future<List<DownloadBatche>> getBatches({String? since}) {
    if (since == null) return select(downloadBatches).get();
    final sinceDt = DateTime.tryParse(since);
    if (sinceDt == null) return select(downloadBatches).get();
    return (select(downloadBatches)
          ..where((t) => t.downloadedAt.isBiggerThanValue(sinceDt)))
        .get();
  }

  Future<DownloadBatche?> getBatchByItem(
    String itemType, String itemId, String source,
  ) => (select(downloadBatches)
        ..where((t) =>
            t.itemType.equals(itemType) &
            t.itemId.equals(itemId) &
            t.source.equals(source)))
      .getSingleOrNull();

  Future<void> removeBatchByItem(
          String itemType, String itemId, String source) =>
      (delete(downloadBatches)
            ..where((t) =>
                t.itemType.equals(itemType) &
                t.itemId.equals(itemId) &
                t.source.equals(source)))
          .go();

  Future<void> removeBatches(List<String> keys) async {
    for (final k in keys) {
      await (delete(downloadBatches)..where((t) => t.batchKey.equals(k))).go();
    }
  }

  /// Cuenta cuántos lotes referencian [trackId] (para borrar el audio solo
  /// cuando ningún otro lote lo usa).
  Future<int> countBatchesReferencingTrack(String trackId) async {
    final batches = await select(downloadBatches).get();
    var count = 0;
    for (final b in batches) {
      final raw = b.trackIds ?? '';
      if (raw.isEmpty || raw == '[]') continue;
      try {
        final ids = (jsonDecode(raw) as List<dynamic>).map((e) => e.toString());
        if (ids.any((id) => id.contains(trackId) || trackId.contains(id))) {
          count++;
        }
      } catch (e) {
        debugPrint("[App] $e");
      }
    }
    return count;
  }
}
