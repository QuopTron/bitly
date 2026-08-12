import '../database/app_database.dart';
import '../database/daos/cache_dao.dart';

/// Read-through JSON cache for album, artist, playlist detail views + user stats.
///
/// Cache key prefixes:
/// - `detail:album:{albumId}`
/// - `detail:artist:{artistId}`
/// - `detail:playlist:{collectionId}`
/// - `detail:userStats`
///
/// Default TTL: 30 minutes. Call [invalidate*] to force a refresh.
class DetailCache {
  final CacheDao _c;
  DetailCache(AppDatabase db) : _c = CacheDao(db);

  /// Default TTL in milliseconds (30 minutes).
  static const int ttlMs = 30 * 60 * 1000;

  // ── Album Detail ────────────────────────────────────────────────

  String _albumKey(String id) => 'detail:album:$id';

  Future<String?> getAlbumDetail(String albumId) =>
      _getIfFresh(_albumKey(albumId));

  Future<void> setAlbumDetail(String albumId, String json) =>
      _c.set(_albumKey(albumId), json);

  Future<void> invalidateAlbum(String albumId) =>
      _c.remove(_albumKey(albumId));

  // ── Artist Detail ───────────────────────────────────────────────

  String _artistKey(String id) => 'detail:artist:$id';

  Future<String?> getArtistDetail(String artistId) =>
      _getIfFresh(_artistKey(artistId));

  Future<void> setArtistDetail(String artistId, String json) =>
      _c.set(_artistKey(artistId), json);

  Future<void> invalidateArtist(String artistId) =>
      _c.remove(_artistKey(artistId));

  // ── Playlist Detail ─────────────────────────────────────────────

  String _playlistKey(String id) => 'detail:playlist:$id';

  Future<String?> getPlaylistDetail(String collectionId) =>
      _getIfFresh(_playlistKey(collectionId));

  Future<void> setPlaylistDetail(String collectionId, String json) =>
      _c.set(_playlistKey(collectionId), json);

  Future<void> invalidatePlaylist(String collectionId) =>
      _c.remove(_playlistKey(collectionId));

  // ── User Stats (incl. level calculation) ────────────────────────

  static const String _statsKey = 'detail:userStats';

  Future<String?> getUserStats() => _getIfFresh(_statsKey);

  Future<void> setUserStats(String json) => _c.set(_statsKey, json);

  Future<void> invalidateUserStats() => _c.remove(_statsKey);

  /// User level + progress calculation (migrated from Go).
  /// Returns a JSON-encodable map with {level, nextLevel, progress}.
  static Map<String, dynamic> calculateLevel({
    required int totalDownloads,
    required int totalLikes,
    required int totalPlaybackMs,
  }) {
    const maxLevel = 6;
    final level = _rawLevel(totalDownloads, totalLikes, totalPlaybackMs);
    final nextLevel = level >= maxLevel ? maxLevel : level + 1;
    final progress = _rawProgress(totalDownloads, totalLikes, totalPlaybackMs, level);
    return {
      'level': level,
      'nextLevel': nextLevel,
      'progress': progress,
    };
  }

  static int _rawLevel(int downloads, int likes, int playbackMs) {
    if (downloads >= 1000 && likes >= 500 && playbackMs >= 360000000) return 6;
    if (downloads >= 500 && likes >= 200 && playbackMs >= 180000000) return 5;
    if (downloads >= 200 && likes >= 100 && playbackMs >= 72000000) return 4;
    if (downloads >= 100 && likes >= 50 && playbackMs >= 36000000) return 3;
    if (downloads >= 50 && likes >= 20 && playbackMs >= 10800000) return 2;
    if (downloads >= 10) return 1;
    return 0;
  }

  static double _rawProgress(int downloads, int likes, int playbackMs, int level) {
    // Requirements per level (downloads, likes, playbackMs)
    const reqs = <(int, int, int)>[
      (10, 0, 0),              // Bronze
      (50, 20, 10800000),      // Silver I
      (100, 50, 36000000),     // Silver II
      (200, 100, 72000000),     // Gold I
      (500, 200, 180000000),   // Gold II
      (1000, 500, 360000000),  // Gold III
    ];
    if (level >= reqs.length) return 1.0;

    final (rd, rl, rp) = reqs[level];
    double progress = 0;
    if (rd > 0) progress += (downloads < rd ? downloads : rd) / rd * 0.4;
    if (rl > 0) progress += (likes < rl ? likes : rl) / rl * 0.3;
    if (rp > 0) progress += (playbackMs < rp ? playbackMs : rp) / rp * 0.3;
    return progress > 1.0 ? 1.0 : progress;
  }

  // ── Bulk operations ─────────────────────────────────────────────

  Future<void> invalidateAll() => _c.removeByPrefix('detail:');

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

