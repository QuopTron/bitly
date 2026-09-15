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

@DriftAccessor(tables: [DownloadQueue, DownloadHistory, DownloadBatches, HiddenDownloadIds])
class DownloadDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadDaoMixin, _DownloadDaoLotes {
  DownloadDao(super.db);

  Future<List<DownloadQueueData>> getQueue() => select(downloadQueue).get();
  Future<List<DownloadQueueData>> getPending() =>
      (select(downloadQueue)..where((t) => t.status.equals('pending'))).get();

  Future<void> enqueue(DownloadQueueCompanion entry) =>
      into(downloadQueue).insert(entry);

  Future<void> updateStatus(String id, String status, {double? progress}) =>
      (update(downloadQueue)..where((t) => t.id.equals(id))).write(
        DownloadQueueCompanion(
          status: Value(status),
          progress: Value(progress ?? 0.0),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> removeFromQueue(String id) =>
      (delete(downloadQueue)..where((t) => t.id.equals(id))).go();

  Future<List<DownloadHistoryData>> getHistory({
    String? since,
    int limit = 100,
    int offset = 0,
  }) {
    // Carga delta: solo entradas más nuevas que [since] para que la caché no
    // relea el historial completo (ni re-verifique archivos) en cada refresh.
    final sinceDt = since == null ? null : DateTime.tryParse(since);
    final q = select(downloadHistory)
      ..orderBy([(t) => OrderingTerm.desc(t.downloadedAt)])
      ..limit(limit, offset: offset);
    if (sinceDt != null) {
      q.where((t) => t.downloadedAt.isBiggerThanValue(sinceDt));
    }
    return q.get();
  }

  Future<int> getHistoryCount() =>
      select(downloadHistory).get().then((r) => r.length);

  Future<void> saveEntry(DownloadHistoryCompanion entry) =>
      into(downloadHistory).insertOnConflictUpdate(entry);

  Future<void> removeById(String id) =>
      (delete(downloadHistory)..where((t) => t.id.equals(id))).go();

  Future<void> clearHistory() => delete(downloadHistory).go();

  Future<List<DownloadHistoryData>> findExisting({
    String? isrc,
    String? trackName,
    String? artistName,
  }) =>
      (select(downloadHistory)
            ..where((t) {
              if (isrc != null && isrc.isNotEmpty) return t.isrc.equals(isrc);
              if (trackName != null && artistName != null) {
                return t.trackName.equals(trackName) &
                    t.artistName.equals(artistName);
              }
              return t.id.equals('');
            }))
          .get();

  Future<String?> getFilePathById(String id) async {
    final rows = await (select(downloadHistory)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first.filePath;
  }

  /// Actualiza file_path del historial (tras decrypt renombra .flac→.dec.flac).
  Future<void> updateFilePath(String id, String newFilePath) =>
      (update(downloadHistory)..where((t) => t.id.equals(id))).write(
        DownloadHistoryCompanion(
          filePath: Value(newFilePath),
        ),
      );

  /// Actualiza la carátula (URL remota + ruta local) de una entrada del
  /// historial. Se usa en el backfill de tracks viejos descargados sin cover.
  Future<void> updateTrackCover(String id, String coverUrl, String coverPath) =>
      (update(downloadHistory)..where((t) => t.id.equals(id))).write(
        DownloadHistoryCompanion(
          coverUrl: Value(coverUrl),
          coverPath: Value(coverPath),
        ),
      );
}
