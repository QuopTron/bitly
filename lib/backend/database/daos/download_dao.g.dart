// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_dao.dart';

// ignore_for_file: type=lint
mixin _$DownloadDaoMixin on DatabaseAccessor<AppDatabase> {
  $DownloadQueueTable get downloadQueue => attachedDatabase.downloadQueue;
  $DownloadHistoryTable get downloadHistory => attachedDatabase.downloadHistory;
  $DownloadBatchesTable get downloadBatches => attachedDatabase.downloadBatches;
  $HiddenDownloadIdsTable get hiddenDownloadIds =>
      attachedDatabase.hiddenDownloadIds;
  DownloadDaoManager get managers => DownloadDaoManager(this);
}

class DownloadDaoManager {
  final _$DownloadDaoMixin _db;
  DownloadDaoManager(this._db);
  $$DownloadQueueTableTableManager get downloadQueue =>
      $$DownloadQueueTableTableManager(_db.attachedDatabase, _db.downloadQueue);
  $$DownloadHistoryTableTableManager get downloadHistory =>
      $$DownloadHistoryTableTableManager(
        _db.attachedDatabase,
        _db.downloadHistory,
      );
  $$DownloadBatchesTableTableManager get downloadBatches =>
      $$DownloadBatchesTableTableManager(
        _db.attachedDatabase,
        _db.downloadBatches,
      );
  $$HiddenDownloadIdsTableTableManager get hiddenDownloadIds =>
      $$HiddenDownloadIdsTableTableManager(
        _db.attachedDatabase,
        _db.hiddenDownloadIds,
      );
}
