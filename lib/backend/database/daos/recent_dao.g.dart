// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_dao.dart';

// ignore_for_file: type=lint
mixin _$RecentDaoMixin on DatabaseAccessor<AppDatabase> {
  $RecentSearchesTable get recentSearches => attachedDatabase.recentSearches;
  $RecentAccessTable get recentAccess => attachedDatabase.recentAccess;
  RecentDaoManager get managers => RecentDaoManager(this);
}

class RecentDaoManager {
  final _$RecentDaoMixin _db;
  RecentDaoManager(this._db);
  $$RecentSearchesTableTableManager get recentSearches =>
      $$RecentSearchesTableTableManager(
        _db.attachedDatabase,
        _db.recentSearches,
      );
  $$RecentAccessTableTableManager get recentAccess =>
      $$RecentAccessTableTableManager(_db.attachedDatabase, _db.recentAccess);
}
