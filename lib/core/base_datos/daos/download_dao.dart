// ---------------------------------------------------------------------------
// download_dao.dart — DAO de descargas: cola, historial, lotes e ids ocultos.
// Las operaciones sobre lotes viven en download_dao_lotes.dart.
// Se conecta con: app_database.dart + CacheDescargas (DownloadCubit).
// Parte del flujo: descargas (cola y historial).
// ---------------------------------------------------------------------------

import "package:flutter/foundation.dart";
import 'dart:convert';
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/download_tables.dart';

part 'download_dao.g.dart';
part 'download_dao_lotes.dart';

@DriftAccessor(
  tables: [DownloadQueue, DownloadHistory, DownloadBatches, HiddenDownloadIds],
)
class DownloadDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadDaoMixin, _DownloadDaoLotes {
  DownloadDao(super.db);

  Future<List<DownloadQueueData>> getQueue() => select(downloadQueue).get();
  Future<List<DownloadQueueData>> getPending() =>
      (select(downloadQueue)..where((t) => t.status.equals('pending'))).get();

  Future<List<DownloadHistoryData>> getHistory({
    String? since,
    int limit = 100,
    int offset = 0,
  }) {
    // Carga delta: solo entradas más nuevas que [since] para que la caché no
    // relea el historial completo (ni re-verifique archivos) en cada refresh.
    final sinceDt = since == null ? null : DateTime.tryParse(since);
    final q =
        select(downloadHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.downloadedAt)])
          ..limit(limit, offset: offset);
    if (sinceDt != null) {
      q.where((t) => t.downloadedAt.isBiggerThanValue(sinceDt));
    }
    return q.get();
  }

  Future<int> getHistoryCount() =>
      select(downloadHistory).get().then((r) => r.length);

  /// Historial COMPLETO (sin el límite de paginación de [getHistory]). Se usa
  /// en tareas de mantenimiento que deben ver todas las filas, como la
  /// re-vinculación de rutas cuando el usuario mueve la carpeta de descargas.
  Future<List<DownloadHistoryData>> getAllHistory() =>
      select(downloadHistory).get();

  Future<void> saveEntry(DownloadHistoryCompanion entry) =>
      into(downloadHistory).insertOnConflictUpdate(entry);

  Future<void> removeById(String id) =>
      (delete(downloadHistory)..where((t) => t.id.equals(id))).go();

  Future<List<DownloadHistoryData>> findExisting({
    String? isrc,
    String? trackName,
    String? artistName,
  }) =>
      (select(downloadHistory)..where((t) {
        if (isrc != null && isrc.isNotEmpty) return t.isrc.equals(isrc);
        if (trackName != null && artistName != null) {
          return t.trackName.equals(trackName) &
              t.artistName.equals(artistName);
        }
        return t.id.equals('');
      })).get();

  Future<String?> getFilePathById(String id) async {
    final rows =
        await (select(downloadHistory)
              ..where((t) => t.id.equals(id))
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first.filePath;
  }

  /// La carátula local de una descarga (la usa el vínculo entre aparatos
  /// para prestarla junto con el audio). Null si no tiene.
  Future<String?> getCoverPathById(String id) async {
    final rows =
        await (select(downloadHistory)
              ..where((t) => t.id.equals(id))
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first.coverPath;
  }

  /// Actualiza file_path del historial (tras decrypt renombra .flac→.dec.flac).
  Future<void> updateFilePath(String id, String newFilePath) =>
      (update(downloadHistory)..where(
        (t) => t.id.equals(id),
      )).write(DownloadHistoryCompanion(filePath: Value(newFilePath)));

  /// Actualiza la carátula (URL remota + ruta local) de una entrada del
  /// historial. Se usa en el backfill de tracks viejos descargados sin cover.
  /// Los campos vacíos NO pisan lo que ya haya: el backfill solo rellena.
  Future<void> updateTrackCover(
    String id,
    String coverUrl,
    String coverPath,
  ) => (update(downloadHistory)..where((t) => t.id.equals(id))).write(
    DownloadHistoryCompanion(
      coverUrl: coverUrl.isNotEmpty ? Value(coverUrl) : const Value.absent(),
      coverPath: coverPath.isNotEmpty ? Value(coverPath) : const Value.absent(),
    ),
  );

  /// Actualiza la carátula de un lote ya guardado (álbum/playlist).
  /// Se usa cuando la carátula se resuelve después de persistir el lote: sin
  /// esto, el álbum quedaba con portada gris en cada arranque.
  /// Igual que [updateTrackCover]: solo rellena, nunca borra.
  Future<void> updateBatchCover(
    String batchKey,
    String coverUrl,
    String coverPath,
  ) => (update(downloadBatches)
    ..where((t) => t.batchKey.equals(batchKey))).write(
    DownloadBatchesCompanion(
      coverUrl: coverUrl.isNotEmpty ? Value(coverUrl) : const Value.absent(),
      coverPath: coverPath.isNotEmpty ? Value(coverPath) : const Value.absent(),
    ),
  );
}
