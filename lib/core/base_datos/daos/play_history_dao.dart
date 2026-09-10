// ---------------------------------------------------------------------------
// play_history_dao.dart — DAO de historial y agregados de reproduccion. Se conecta con: app_database.dart + player (report de plays). Parte del flujo: Recientes y Estadisticas.
// ---------------------------------------------------------------------------

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

  /// Sum of every play count for [type] (the real total, NOT capped by a
  /// top-N limit like [getTop]).
  Future<int> sumPlayCounts(String type) =>
      (selectOnly(playAggregates)
            ..addColumns([playAggregates.playCount.sum()])
            ..where(playAggregates.type.equals(type)))
          .map((r) => r.read(playAggregates.playCount.sum()) ?? 0)
          .getSingle();

  /// Number of distinct aggregated items for [type] (unique tracks/albums/…).
  Future<int> countAggregates(String type) =>
      (selectOnly(playAggregates)
            ..addColumns([playAggregates.itemId.count()])
            ..where(playAggregates.type.equals(type)))
          .map((r) => r.read(playAggregates.itemId.count()) ?? 0)
          .getSingle();

  /// Number of distinct (non-empty) artist names ever played.
  Future<int> getDistinctArtistsCount() async {
    final rows = await (select(playHistory)
          ..where((t) => t.artistName.isNotIn(const [''])))
        .get();
    return rows.map((r) => r.artistName).toSet().length;
  }

  /// Latest known name/artist for the most recent played tracks, so the
  /// "most played" list can show real titles instead of raw ids.
  Future<Map<String, ({String name, String artist})>> getLatestNames() async {
    final rows = await (select(playHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
          ..limit(500))
        .get();
    final map = <String, ({String name, String artist})>{};
    for (final r in rows) {
      map.putIfAbsent(
        r.trackId ?? '',
        () => (name: r.trackName, artist: r.artistName),
      );
    }
    return map;
  }
}

