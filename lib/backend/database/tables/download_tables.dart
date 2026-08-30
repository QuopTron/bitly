import 'package:drift/drift.dart';

@TableIndex(name: 'idx_dl_queue_status', columns: {#status})
class DownloadQueue extends Table {
  TextColumn get id => text()();
  TextColumn get trackJson => text()();
  TextColumn? get itemJson => text().nullable()();
  TextColumn get status => text().customConstraint("NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'downloading', 'completed', 'failed'))")();
  RealColumn get progress => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_dl_history_isrc', columns: {#isrc})
@TableIndex(name: 'idx_dl_history_downloaded_at', columns: {#downloadedAt})
class DownloadHistory extends Table {
  TextColumn get id => text()();
  TextColumn get trackName => text()();
  TextColumn get artistName => text()();
  TextColumn? get albumName => text().nullable()();
  TextColumn? get isrc => text().nullable()();
  TextColumn? get filePath => text().nullable()();
  TextColumn? get service => text().nullable()();
  IntColumn get duration => integer().nullable()();
  DateTimeColumn get downloadedAt => dateTime()();
  TextColumn? get providerTrackId => text().nullable()();
  TextColumn? get providerSource => text().nullable()();
  TextColumn? get coverUrl => text().nullable()();
  TextColumn? get coverPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_dl_batches_item', columns: {#itemId, #itemType})
class DownloadBatches extends Table {
  TextColumn get batchKey => text()();
  TextColumn? get itemType => text().nullable()();
  TextColumn? get itemId => text().nullable()();
  TextColumn? get source => text().nullable()();
  TextColumn? get name => text().nullable()();
  TextColumn? get trackIds => text().nullable()();
  TextColumn? get coverUrl => text().nullable()();
  TextColumn? get coverPath => text().nullable()();
  DateTimeColumn get downloadedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {batchKey};
}

class HiddenDownloadIds extends Table {
  TextColumn get downloadId => text()();

  @override
  Set<Column> get primaryKey => {downloadId};
}

