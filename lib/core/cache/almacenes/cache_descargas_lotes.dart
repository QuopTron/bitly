// ─────────────────────────────────────────────────────────────
// cache_descargas_lotes.dart — PART de cache_descargas.dart: lectura y
// mantenimiento de LOTES de descarga (álbum/playlist) y de la ruta de
// archivo del historial — consultar por ítem, contar lotes que
// referencian un track, actualizar la ruta tras un renombrado del
// decrypt, hacer backfill de la carátula y re-vincular TODAS las
// rutas cuando el usuario mueve la carpeta de descargas.
// Se conecta con: cache_descargas.dart (misma library) + DownloadDao.
// Parte del flujo: descargas (lotes e historial en disco).
// ─────────────────────────────────────────────────────────────

part of 'cache_descargas.dart';

extension CacheDescargasLotes on CacheDescargas {
  Future<String?> getRutaArchivoPorId(String id) => _dao.getFilePathById(id);

  Future<DownloadBatche?> getLotePorItem(
    String itemType,
    String itemId,
    String source,
  ) => _dao.getBatchByItem(itemType, itemId, source);

  Future<void> quitarLotePorItem(
    String itemType,
    String itemId,
    String source,
  ) => _dao.removeBatchByItem(itemType, itemId, source);

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

  /// Re-vincula el historial con los archivos que hoy viven en [nuevaCarpeta].
  ///
  /// Por qué existe: si el usuario MUEVE o cambia la carpeta de descargas, las
  /// rutas guardadas apuntan a la ubicación vieja; la biblioteca daría esos
  /// tracks por perdidos aunque los archivos estén enteros en la carpeta nueva.
  /// Se decide con la lógica pura de [planificarRelink] y se aplica acá.
  /// Devuelve cuántas filas cambiaron de ruta (0 = nada que hacer).
  Future<int> reubicarArchivosEnCarpeta(String nuevaCarpeta) async {
    if (nuevaCarpeta.isEmpty) return 0;
    try {
      final filas = await _dao.getAllHistory();
      if (filas.isEmpty) return 0;
      final rutasNuevas = <String>[];
      for (final f in io.Directory(nuevaCarpeta).listSync(followLinks: false)) {
        if (f is io.File) rutasNuevas.add(f.path);
      }
      if (rutasNuevas.isEmpty) return 0;

      final plan = planificarRelink(
        entradas:
            filas
                .map(
                  (f) => EntradaHistorialDescarga(
                    id: f.id,
                    ruta: f.filePath ?? '',
                    caratula: f.coverPath ?? '',
                  ),
                )
                .toList(),
        carpeta: ArchivosEnCarpeta.desde(rutasNuevas),
        // Consulta real al disco: una ruta que sigue existiendo no se toca.
        existe: (r) => r.isNotEmpty && io.File(r).existsSync(),
      );
      if (plan.vacio) return 0;

      final coverUrlPorId = {for (final f in filas) f.id: f.coverUrl ?? ''};
      for (final e in plan.rutas.entries) {
        await _dao.updateFilePath(e.key, e.value);
      }
      for (final e in plan.caratulas.entries) {
        // Conserva la URL remota: acá solo cambió la ruta LOCAL del archivo.
        await _dao.updateTrackCover(e.key, coverUrlPorId[e.key] ?? '', e.value);
      }
      debugPrint(
        '[Relink] ${plan.total} descarga(s) re-vinculada(s) en $nuevaCarpeta',
      );
      return plan.total;
    } catch (e) {
      debugPrint('[Relink] error re-vinculando en $nuevaCarpeta: $e');
      return 0;
    }
  }
}
