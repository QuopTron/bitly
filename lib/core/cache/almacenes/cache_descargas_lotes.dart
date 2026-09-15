// ─────────────────────────────────────────────────────────────
// cache_descargas_lotes.dart — PART de cache_descargas.dart: lectura y
// mantenimiento de LOTES de descarga (álbum/playlist) y de la ruta de
// archivo del historial — consultar por ítem, contar lotes que
// referencian un track, actualizar la ruta tras un renombrado del
// decrypt y hacer backfill de la carátula.
// Se conecta con: cache_descargas.dart (misma library) + DownloadDao.
// Parte del flujo: descargas (lotes e historial en disco).
// ─────────────────────────────────────────────────────────────

part of 'cache_descargas.dart';

extension CacheDescargasLotes on CacheDescargas {
  Future<String?> getRutaArchivoPorId(String id) => _dao.getFilePathById(id);

  Future<DownloadBatche?> getLotePorItem(String itemType, String itemId, String source) =>
      _dao.getBatchByItem(itemType, itemId, source);

  Future<void> quitarLotePorItem(String itemType, String itemId, String source) =>
      _dao.removeBatchByItem(itemType, itemId, source);

  Future<void> quitarLotes(List<String> keys) => _dao.removeBatches(keys);

  /// Cuenta cuántos lotes referencian [trackId] en su track_ids.
  Future<int> contarLotesReferenciandoTrack(String trackId) =>
      _dao.countBatchesReferencingTrack(trackId);

  /// Actualiza la ruta de archivo de una entrada del historial.
  /// Se usa cuando el archivo real en disco difiere del guardado
  /// (p.ej. tras renombrar .flac → .dec.flac por el decrypt).
  Future<void> actualizarRutaArchivo(String id, String nuevaRuta) =>
      _dao.updateFilePath(id, nuevaRuta);

  /// Backfill de carátula de una entrada del historial (tracks viejos
  /// descargados sin cover: les faltaba cover_url al momento de descargar).
  Future<void> actualizarCaratulaTrack(
    String id,
    String coverUrl,
    String coverPath,
  ) => _dao.updateTrackCover(id, coverUrl, coverPath);
}
