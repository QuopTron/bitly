import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/recent_table.dart';

part 'recent_dao.g.dart';

@DriftAccessor(tables: [RecentSearches, RecentAccess])
class RecentDao extends DatabaseAccessor<AppDatabase> with _$RecentDaoMixin {
  RecentDao(super.db);

  Future<List<String>> getRecentSearches({int limit = 10}) async {
    final rows = await (select(recentSearches)
          ..orderBy([(t) => OrderingTerm.desc(t.searchedAt)])
          ..limit(limit))
        .get();
    return rows.map((r) => r.query).toList();
  }

  Future<void> saveSearch(String query) =>
      into(recentSearches).insert(RecentSearchesCompanion(
        query: Value(query),
        searchedAt: Value(DateTime.now()),
      ), mode: InsertMode.insertOrReplace);

  Future<void> removeSearch(String query) =>
      (delete(recentSearches)..where((t) => t.query.equals(query))).go();

  Future<void> clearSearches() => delete(recentSearches).go();

  Future<void> upsertAccess(String key, String json) =>
      into(recentAccess).insert(RecentAccessCompanion(
        key: Value(key),
        itemJson: Value(json),
        accessedAt: Value(DateTime.now()),
      ), mode: InsertMode.insertOrReplace);

  Future<List<RecentAccessData>> getRecentAccess({int limit = 30}) =>
      (select(recentAccess)
            ..orderBy([(t) => OrderingTerm.desc(t.accessedAt)])
            ..limit(limit))
          .get();

  Future<void> removeAccess(String key) =>
      (delete(recentAccess)..where((t) => t.key.equals(key))).go();

  Future<void> clearAccess() => delete(recentAccess).go();
}

