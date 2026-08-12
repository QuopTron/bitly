import '../database/app_database.dart';
import '../database/daos/cache_dao.dart';

/// Read-through JSON cache for Local Library queries (page, count, album groups).
///
/// Cache key prefixes:
/// - `library:page:{limit}:{offset}:{searchQuery}:{sortMode}`
/// - `library:count:{searchQuery}`
/// - `library:albumGroups:{limit}:{offset}:{searchQuery}`
/// - `library:albumGroupCount:{searchQuery}`
/// - `library:singleTrackCount:{searchQuery}`
///
/// Default TTL: 30 minutes. Call [invalidateAll] after a library scan or download.
class LibraryCache {
  final CacheDao _c;
  LibraryCache(AppDatabase db) : _c = CacheDao(db);

  /// Default TTL in milliseconds (30 minutes).
  static const int ttlMs = 30 * 60 * 1000;

  // ── Local Library Page ──────────────────────────────────────────

  String _pageKey(int limit, int offset, String searchQuery, String sortMode) =>
      'library:page:$limit:$offset:${searchQuery.hashCode}:${sortMode.hashCode}';

  Future<String?> getLocalLibraryPage({
    required int limit,
    required int offset,
    String searchQuery = '',
    String sortMode = '',
  }) =>
      _getIfFresh(_pageKey(limit, offset, searchQuery, sortMode));

  Future<void> setLocalLibraryPage({
    required int limit,
    required int offset,
    String searchQuery = '',
    String sortMode = '',
    required String json,
  }) =>
      _c.set(_pageKey(limit, offset, searchQuery, sortMode), json);

  // ── Local Library Count ─────────────────────────────────────────

  String _countKey(String searchQuery) =>
      'library:count:${searchQuery.hashCode}';

  Future<String?> getLocalLibraryCount({String searchQuery = ''}) =>
      _getIfFresh(_countKey(searchQuery));

  Future<void> setLocalLibraryCount({
    String searchQuery = '',
    required String json,
  }) =>
      _c.set(_countKey(searchQuery), json);

  // ── Album Groups ────────────────────────────────────────────────

  String _albumGroupsKey(int limit, int offset, String searchQuery) =>
      'library:albumGroups:$limit:$offset:${searchQuery.hashCode}';

  Future<String?> getLocalLibraryAlbumGroups({
    required int limit,
    required int offset,
    String searchQuery = '',
  }) =>
      _getIfFresh(_albumGroupsKey(limit, offset, searchQuery));

  Future<void> setLocalLibraryAlbumGroups({
    required int limit,
    required int offset,
    String searchQuery = '',
    required String json,
  }) =>
      _c.set(_albumGroupsKey(limit, offset, searchQuery), json);

  // ── Album Group Count ───────────────────────────────────────────

  String _albumGroupCountKey(String searchQuery) =>
      'library:albumGroupCount:${searchQuery.hashCode}';

  Future<String?> getLocalLibraryAlbumGroupCount({String searchQuery = ''}) =>
      _getIfFresh(_albumGroupCountKey(searchQuery));

  Future<void> setLocalLibraryAlbumGroupCount({
    String searchQuery = '',
    required String json,
  }) =>
      _c.set(_albumGroupCountKey(searchQuery), json);

  // ── Single Track Count ──────────────────────────────────────────

  String _singleTrackCountKey(String searchQuery) =>
      'library:singleTrackCount:${searchQuery.hashCode}';

  Future<String?> getLocalLibrarySingleTrackCount({String searchQuery = ''}) =>
      _getIfFresh(_singleTrackCountKey(searchQuery));

  Future<void> setLocalLibrarySingleTrackCount({
    String searchQuery = '',
    required String json,
  }) =>
      _c.set(_singleTrackCountKey(searchQuery), json);

  // ── Bulk operations ─────────────────────────────────────────────

  /// Invalidate all library cache entries. Call after a library scan or
  /// download completes to ensure fresh data on next request.
  Future<void> invalidateAll() => _c.removeByPrefix('library:');

  // ── Internal helpers ────────────────────────────────────────────

  Future<String?> _getIfFresh(String key) async {
    final ts = await _c.getTimestamp(key);
    if (ts == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > ttlMs) {
      await _c.remove(key);
      return null;
    }
    return _c.get(key);
  }
}

