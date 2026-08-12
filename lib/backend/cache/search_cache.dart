import '../database/app_database.dart';
import '../database/daos/recent_dao.dart';

/// Recent searches + recent access local cache — wrappers over [RecentDao].
class SearchCache {
  final RecentDao _r;
  SearchCache(AppDatabase db) : _r = RecentDao(db);

  // ── Recent Searches ─────────────────────────────────────────────

  Future<List<String>> getRecentSearches({int limit = 10}) =>
      _r.getRecentSearches(limit: limit);

  Future<void> saveRecentSearch(String query) => _r.saveSearch(query);
  Future<void> removeRecentSearch(String query) => _r.removeSearch(query);
  Future<void> clearRecentSearches() => _r.clearSearches();

  // ── Recent Access ───────────────────────────────────────────────

  Future<void> upsertRecentAccess(String key, String json) =>
      _r.upsertAccess(key, json);

  Future<void> removeRecentAccess(String key) => _r.removeAccess(key);
  Future<void> clearRecentAccess() => _r.clearAccess();
}

