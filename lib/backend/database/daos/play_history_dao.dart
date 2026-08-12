import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/play_history_table.dart';

part 'play_history_dao.g.dart';

@DriftAccessor(tables: [PlayHistory, PlayAggregates])
class PlayHistoryDao extends DatabaseAccessor<AppDatabase> with _$PlayHistoryDaoMixin {
  PlayHistoryDao(super.db);

  Future<void> logPlay(PlayHistoryCompanion entry) =>
      into(playHistory).insert(entry);

  Future<List<PlayHistoryData>> getRecent({int limit = 20}) =>
      (select(playHistory)
            ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
            ..limit(limit))
          .get();

  Future<void> clear() => delete(playHistory).go();

  Future<void> incrementPlayCount(String itemId, String type) {
    final now = DateTime.now();
    return into(playAggregates).insert(PlayAggregatesCompanion(
      itemId: Value(itemId),
      type: Value(type),
      playCount: const Value(1),
      lastPlayedAt: Value(now),
    ), mode: InsertMode.insertOrReplace);
  }

  Future<List<PlayAggregate>> getTop(String type, {int limit = 20}) =>
      (select(playAggregates)
            ..where((t) => t.type.equals(type))
            ..orderBy([(t) => OrderingTerm.desc(t.playCount)])
            ..limit(limit))
          .get();

  /// Total playback time in milliseconds across all played tracks.
  Future<int> getTotalPlaybackMs() =>
      (select(playHistory)
            ..where((t) => t.durationMs.isNotNull()))
          .get()
          .then((rows) => rows.fold<int>(0, (sum, r) => sum + (r.durationMs ?? 0)));
}

