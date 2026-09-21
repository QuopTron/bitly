// ---------------------------------------------------------------------------
// recent_dao.dart — DAO de recientes (historial de busquedas). Se conecta con: app_database.dart + caches. Parte del flujo: Busqueda (historial).
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';
import '../../../app_database.dart';
import '../../../tables/musica/historial/recent_table.dart';

part 'recent_dao.g.dart';

@DriftAccessor(tables: [RecentSearches])
class RecentDao extends DatabaseAccessor<AppDatabase> with _$RecentDaoMixin {
  RecentDao(super.db);

  Future<List<String>> getRecentSearches({int limit = 10}) async {
    final rows =
        await (select(recentSearches)
              ..orderBy([(t) => OrderingTerm.desc(t.searchedAt)])
              ..limit(limit))
            .get();
    return rows.map((r) => r.query).toList();
  }

  Future<void> saveSearch(String query) => into(recentSearches).insert(
    RecentSearchesCompanion(
      query: Value(query),
      searchedAt: Value(DateTime.now()),
    ),
    mode: InsertMode.insertOrReplace,
  );

  Future<void> removeSearch(String query) =>
      (delete(recentSearches)..where((t) => t.query.equals(query))).go();

  Future<void> clearSearches() => delete(recentSearches).go();
}
