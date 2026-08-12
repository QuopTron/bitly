import 'package:drift/drift.dart';

@TableIndex(name: 'idx_recent_searches_date', columns: {#searchedAt})
class RecentSearches extends Table {
  TextColumn get query => text()();
  DateTimeColumn get searchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {query};
}

@TableIndex(name: 'idx_recent_access_date', columns: {#accessedAt})
class RecentAccess extends Table {
  TextColumn get key => text()();
  TextColumn get itemJson => text()();
  TextColumn? get type => text().nullable()();
  DateTimeColumn get accessedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

