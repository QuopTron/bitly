// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_dao.dart';

// ignore_for_file: type=lint
mixin _$DownloadDaoMixin on DatabaseAccessor<AppDatabase> {
  $DownloadHistoryTable get downloadHistory => attachedDatabase.downloadHistory;
  $DownloadBatchesTable get downloadBatches => attachedDatabase.downloadBatches;
  DownloadDaoManager get managers => DownloadDaoManager(this);
}

class DownloadDaoManager {
  final _$DownloadDaoMixin _db;
  DownloadDaoManager(this._db);
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
}
