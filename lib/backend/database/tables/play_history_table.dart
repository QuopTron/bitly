import 'package:drift/drift.dart';

@TableIndex(name: 'idx_play_history_played_at', columns: {#playedAt})
class PlayHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn? get trackId => text().nullable()();
  TextColumn get trackName => text()();
  TextColumn get artistName => text()();
  TextColumn? get albumName => text().nullable()();
  DateTimeColumn get playedAt => dateTime()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get percentage => integer().nullable()();
}

@TableIndex(name: 'idx_play_agg_type_count', columns: {#type, #playCount})
class PlayAggregates extends Table {
  TextColumn get itemId => text()();
  TextColumn get type => text().customConstraint("NOT NULL CHECK(type IN ('track', 'album', 'artist'))")();
  IntColumn get playCount => integer().nullable()();
  DateTimeColumn? get lastPlayedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {itemId};
}

