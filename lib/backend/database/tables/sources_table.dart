import 'package:drift/drift.dart';
import 'content_tables.dart';

@TableIndex(name: 'idx_sources_track_id', columns: {#trackId})
class Sources extends Table {
  TextColumn get id => text()();
  TextColumn get trackId => text().references(Tracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get provider => text()();
  TextColumn get externalId => text()();
  TextColumn? get quality => text().nullable()();
  TextColumn? get audioQuality => text().nullable()();
  TextColumn? get coverUrl => text().nullable()();
  TextColumn? get metadataJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Files extends Table {
  TextColumn get id => text()();
  TextColumn? get trackId => text().references(Tracks, #id, onDelete: KeyAction.cascade).nullable()();
  TextColumn? get metadataId => text().nullable()();
  TextColumn? get sourceId => text().references(Sources, #id, onDelete: KeyAction.setNull).nullable()();
  TextColumn get filePath => text().unique()();
  TextColumn get sourceType => text().customConstraint("NOT NULL CHECK(source_type IN ('download', 'local_scan'))")();
  TextColumn? get format => text().nullable()();
  IntColumn get bitrate => integer().nullable()();
  IntColumn get bitDepth => integer().nullable()();
  IntColumn get sampleRate => integer().nullable()();
  DateTimeColumn? get downloadedAt => dateTime().nullable()();
  DateTimeColumn? get scannedAt => dateTime().nullable()();
  IntColumn get fileModTime => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

