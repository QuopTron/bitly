import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/download_tables.dart';

part 'download_dao.g.dart';

@DriftAccessor(tables: [DownloadQueue, DownloadHistory, DownloadBatches, HiddenDownloadIds])
class DownloadDao extends DatabaseAccessor<AppDatabase> with _$DownloadDaoMixin {
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
    // Delta loading: only fetch entries newer than [since] so the download
    // cache doesn't re-read the full history (and re-check every file exists)
    // on every 30s refresh / track switch.
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
}

