// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play_history_dao.dart';

// ignore_for_file: type=lint
mixin _$PlayHistoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $PlayHistoryTable get playHistory => attachedDatabase.playHistory;
  $PlayAggregatesTable get playAggregates => attachedDatabase.playAggregates;
  PlayHistoryDaoManager get managers => PlayHistoryDaoManager(this);
}

class PlayHistoryDaoManager {
  final _$PlayHistoryDaoMixin _db;
  PlayHistoryDaoManager(this._db);
  $$PlayHistoryTableTableManager get playHistory =>
      $$PlayHistoryTableTableManager(_db.attachedDatabase, _db.playHistory);
  $$PlayAggregatesTableTableManager get playAggregates =>
      $$PlayAggregatesTableTableManager(
        _db.attachedDatabase,
        _db.playAggregates,
      );
}
