// ---------------------------------------------------------------------------
// download_tables.dart — Tablas de descargas: historial y lotes (batch). Se conecta con: daos/download_dao.dart + DownloadCubit. Parte del flujo: descargas (Mi Espacio y boton de descarga).
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';

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
