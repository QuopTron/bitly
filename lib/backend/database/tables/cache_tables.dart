import 'package:drift/drift.dart';

class IsrcCache extends Table {
  TextColumn get isrc => text()();
  TextColumn get genre => text().customConstraint("NOT NULL DEFAULT ''")();
  TextColumn get albumArtist => text().customConstraint("NOT NULL DEFAULT ''")();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column> get primaryKey => {isrc};
}

@TableIndex(name: 'idx_video_cache_lookup', columns: {#trackName, #artistName})
class VideoUrlCache extends Table {
  TextColumn get id => text()();
  TextColumn get trackName => text()();
  TextColumn get artistName => text()();
  TextColumn get url => text()();
  TextColumn? get source => text().nullable()();
  IntColumn get cachedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Generic JSON cache for Detail Views + Local Library responses.
/// Key format: "detail:album:{id}", "detail:artist:{id}", "detail:playlist:{id}",
/// "detail:userStats", "library:page:{limit}:{offset}", "library:count",
/// "library:albumGroups:{limit}:{offset}", "library:albumGroupCount",
/// "library:singleTrackCount".
class JsonCache extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  IntColumn get timestamp => integer()(); // epoch millis UTC

  @override
  Set<Column> get primaryKey => {key};
}

