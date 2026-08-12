import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/daos/play_history_dao.dart';
import '../database/daos/premium_dao.dart';
import '../database/daos/download_dao.dart';
import '../database/daos/favorites_dao.dart';
import '../database/daos/collections_dao.dart';
import '../database/daos/content_dao.dart';
import 'detail_cache.dart';
import '../../frontend/shared/models/detail_models.dart';

final _log = Logger();

/// Local cache for play history, aggregates, daily plays, and listening level.
///
/// Replaces the following Go RPCs:
/// - `logPlayV2JSON` → [logPlay]
/// - `getRecentPlaysV2JSON` → [getRecentPlays]
/// - `getPlayStatsV2JSON` → [getPlayStats]
/// - `getListeningLevelV2JSON` → [getListeningLevel]
class PlaybackCache {
  final PlayHistoryDao _ph;
  final PremiumDao _pm;
  final DownloadDao _dl;
  final FavoritesDao _fv;
  final CollectionsDao _cl;
  final ContentDao _ct;

  PlaybackCache(AppDatabase db)
      : _ph = PlayHistoryDao(db),
        _pm = PremiumDao(db),
        _dl = DownloadDao(db),
        _fv = FavoritesDao(db),
        _cl = CollectionsDao(db),
        _ct = ContentDao(db);

  /// Record a play in local Drift tables:
  /// 1. Insert into `play_history`
  /// 2. Increment `play_aggregates` for the track
  /// 3. Increment `user_daily_plays` for today
  Future<void> logPlay({
    required String trackId,
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationMs,
    int? percentage,
  }) async {
    final now = DateTime.now();

    // 1. Insert play history entry
    await _ph.logPlay(PlayHistoryCompanion(
      trackId: Value(trackId),
      trackName: Value(trackName),
      artistName: Value(artistName),
      albumName: Value(albumName ?? ''),
      playedAt: Value(now),
      durationMs: Value(durationMs),
      percentage: Value(percentage),
    ));

    // 2. Increment play aggregates for track
    await _ph.incrementPlayCount(trackId, 'track');

    // 3. Increment daily play count
    final today = now.toUtc().toIso8601String().substring(0, 10);
    await _pm.incrementDailyPlayCount(today);
  }

  /// Get recent plays from local play_history.
  Future<List<PlayHistoryData>> getRecentPlays({int limit = 50}) =>
      _ph.getRecent(limit: limit);

  /// Get top play stats for a type (track, album, artist).
  Future<List<PlayAggregate>> getPlayStats(String type, {int limit = 20}) =>
      _ph.getTop(type, limit: limit);

  /// Calculate listening level and daily limit based on local data.
  ///
  /// Returns a map matching the same shape as the old Go response:
  /// {level, totalPlays, dailyLimit, playsToday, playsRemaining, blocked}
  Future<Map<String, dynamic>> getListeningLevel() async {
    final topTracks = await _ph.getTop('track');
    final totalPlays =
        topTracks.fold<int>(0, (sum, t) => sum + (t.playCount ?? 0));

    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final playsToday = await _pm.getDailyPlayCount(today);

    final premium = await _pm.getPremium();
    final isPremium = premium != null && premium.tier != 'free';

    String level = 'free';
    int dailyLimit = 50;

    if (totalPlays >= 10000) {
      level = 'legend';
      dailyLimit = 999999;
    } else if (totalPlays >= 5000) {
      level = 'gold';
      dailyLimit = 300;
    } else if (totalPlays >= 1000) {
      level = 'silver';
      dailyLimit = 200;
    } else if (totalPlays >= 100) {
      level = 'bronze';
      dailyLimit = 100;
    }

    if (isPremium) {
      final p = premium;
      if (p.tier == 'lifetime') {
        level = 'legend';
        dailyLimit = 999999;
      } else {
        dailyLimit = 500;
        if (totalPlays >= 5000) {
          level = 'legend';
          dailyLimit = 999999;
        } else if (totalPlays >= 1000) {
          level = 'gold';
        } else {
          level = 'premium';
        }
      }
    }

    _log.i('[PlaybackCache] level=$level totalPlays=$totalPlays dailyLimit=$dailyLimit playsToday=$playsToday isPremium=$isPremium');

    return {
      'level': level,
      'totalPlays': totalPlays,
      'dailyLimit': dailyLimit,
      'playsToday': playsToday,
      'playsRemaining': dailyLimit - playsToday,
      'blocked': playsToday >= dailyLimit,
    };
  }

  /// Aggregate user stats from local Drift tables, replacing Go's GetUserStatsV2.
  ///
  /// Returns a [UserStats] object with totals, level, and progress.
  Future<UserStats> getUserStats() async {
    final totalDownloads = await _dl.getHistoryCount();
    final totalLikes = (await _fv.getLovedTracks()).length;
    final totalPlaybackMs = await _ph.getTotalPlaybackMs();
    final totalPlaylistTracks = await _cl.getCollectionItemsCount();
    final totalTracks = await _ct.getTrackCount();
    final totalAlbums = await _ct.getAlbumCount();
    final totalArtists = await _ct.getArtistCount();

    // Calculate level & progress (same logic as Go's calculateLevel)
    final levelData = DetailCache.calculateLevel(
      totalDownloads: totalDownloads,
      totalLikes: totalLikes,
      totalPlaybackMs: totalPlaybackMs,
    );

    return UserStats(
      totalDownloads: totalDownloads,
      totalLikes: totalLikes,
      totalPlaybackMs: totalPlaybackMs,
      totalPlaylistTracks: totalPlaylistTracks,
      totalTracks: totalTracks,
      totalAlbums: totalAlbums,
      totalArtists: totalArtists,
      level: levelData['level'] as int? ?? 0,
      nextLevel: levelData['nextLevel'] as int? ?? 1,
      progress: levelData['progress'] as double? ?? 0.0,
    );
  }

  /// [getUserStats] as a JSON-encoded string (for BackendService compatibility).
  Future<String> getUserStatsJSON() async {
    final stats = await getUserStats();
    return jsonEncode({
      'totalDownloads': stats.totalDownloads,
      'totalLikes': stats.totalLikes,
      'totalPlaybackMs': stats.totalPlaybackMs,
      'totalPlaylistTracks': stats.totalPlaylistTracks,
      'totalTracks': stats.totalTracks,
      'totalAlbums': stats.totalAlbums,
      'totalArtists': stats.totalArtists,
      'level': stats.level,
      'nextLevel': stats.nextLevel,
      'progress': stats.progress,
    });
  }

  // ── Artist Stats (local Drift) ─────────────────────────────────

  /// Get top tracks for an artist, sorted by play count descending.
  Future<List<DetailTrack>> getArtistTopTracks(String artistId, {int limit = 20}) async {
    final tracks = await _ct.getTracksByArtist(artistId);
    final playAggs = await _ph.getTop('track', limit: 1000);
    final playMap = {for (final a in playAggs) a.itemId: a.playCount ?? 0};

    final sorted = tracks.map((t) {
      final pc = playMap[t.id] ?? 0;
      return (track: t, playCount: pc);
    }).toList()
      ..sort((a, b) {
        final cmp = b.playCount.compareTo(a.playCount);
        if (cmp != 0) return cmp;
        return a.track.name.compareTo(b.track.name);
      });

    return sorted.take(limit).map((e) => DetailTrack(
      trackId: e.track.id,
      name: e.track.name,
      durationMs: e.track.durationMs ?? 0,
      trackNumber: e.track.trackNumber ?? 0,
      isrc: e.track.isrc ?? '',
      coverUrl: e.track.coverUrl,
      coverPath: e.track.coverPath,
      provider: e.track.source,
    )).toList();
  }

  /// Get top albums for an artist, sorted by play count descending.
  Future<List<DetailAlbum>> getArtistTopAlbums(String artistId, {int limit = 10}) async {
    final albums = await _ct.getAlbumsByArtist(artistId);
    final playAggs = await _ph.getTop('album', limit: 1000);
    final playMap = {for (final a in playAggs) a.itemId: a.playCount ?? 0};

    final sorted = albums.map((a) {
      final pc = playMap[a.id] ?? 0;
      return (album: a, playCount: pc);
    }).toList()
      ..sort((a, b) {
        final cmp = b.playCount.compareTo(a.playCount);
        if (cmp != 0) return cmp;
        return (a.album.releaseDate ?? '').compareTo(b.album.releaseDate ?? '');
      });

    return sorted.take(limit).map((e) => DetailAlbum(
      albumId: e.album.id,
      name: e.album.name,
      coverUrl: e.album.coverUrl,
      coverPath: e.album.coverPath,
      releaseDate: e.album.releaseDate,
      totalTracks: e.album.totalTracks ?? 0,
      playCount: e.playCount,
    )).toList();
  }

  /// Get similar artists from local Drift SimilarArtists table.
  Future<List<Map<String, dynamic>>> getSimilarArtists(String artistId) async {
    final similar = await _ct.getSimilarArtists(artistId);
    final result = <Map<String, dynamic>>[];
    for (final s in similar) {
      final artist = await _ct.getArtist(s.similarArtistId);
      result.add({
        'artistId': s.similarArtistId,
        'artistName': artist?.name ?? '',
        'imageUrl': artist?.imageUrl ?? '',
        'imagePath': artist?.imagePath ?? '',
        'score': s.similarityScore ?? 0.0,
      });
    }
    return result;
  }

  /// Build a full ArtistDetail from local Drift data, or null if artist not found.
  Future<ArtistDetail?> getArtistDetailLocal(String artistId) async {
    final artist = await _ct.getArtist(artistId);
    if (artist == null) return null;

    final topTracks = await getArtistTopTracks(artistId);
    final topAlbums = await getArtistTopAlbums(artistId);

    return ArtistDetail(
      id: artist.id,
      name: artist.name,
      imageUrl: artist.imageUrl,
      imagePath: artist.imagePath,
      topTracks: topTracks,
      topAlbums: topAlbums,
    );
  }

  // ── Album Detail (local Drift) ─────────────────────────────────

  /// Build an AlbumDetail from local Drift data, or null if album not found.
  Future<AlbumDetail?> getAlbumDetailLocal(String albumId) async {
    final album = await _ct.getAlbum(albumId);
    if (album == null) return null;

    final albumTracks = await _ct.getTracksByAlbum(albumId);
    final artist = await _ct.getArtist(album.artistId);

    final tracks = albumTracks.map((t) => DetailTrack(
      trackId: t.id,
      name: t.name,
      durationMs: t.durationMs ?? 0,
      trackNumber: t.trackNumber ?? 0,
      isrc: t.isrc ?? '',
      coverUrl: t.coverUrl,
      coverPath: t.coverPath,
      artistName: artist?.name,
      albumName: album.name,
      provider: t.source,
    )).toList();

    return AlbumDetail(
      id: album.id,
      name: album.name,
      coverUrl: album.coverUrl,
      coverPath: album.coverPath,
      artistName: artist?.name,
      releaseDate: album.releaseDate,
      albumType: album.albumType,
      totalTracks: album.totalTracks ?? 0,
      tracks: tracks,
    );
  }

  /// Save extension-fetched album detail to local Drift tables.
  Future<void> syncAlbumDetail(AlbumDetail detail, {String? source}) async {
    // Upsert artist if name available
    if (detail.artistName != null && detail.artistName!.isNotEmpty) {
      await _ct.upsertArtist(ArtistsCompanion(
        id: Value(detail.id), // album ID used as artist placeholder; real ID unknown
        name: Value(detail.artistName!),
        normalizedName: Value(detail.artistName!.trim().toLowerCase()),
        provider: Value(source ?? ''),
        createdAt: Value(DateTime.now()),
      ));
    }

    await _ct.upsertAlbum(AlbumsCompanion(
      id: Value(detail.id),
      name: Value(detail.name),
      normalizedName: Value(detail.name.trim().toLowerCase()),
      artistId: Value(detail.id), // placeholder; real artist ID unknown
      coverUrl: Value(detail.coverUrl ?? ''),
      coverPath: Value(detail.coverPath ?? ''),
      releaseDate: Value(detail.releaseDate ?? ''),
      albumType: Value(detail.albumType ?? ''),
      totalTracks: Value(detail.totalTracks),
      provider: Value(source ?? ''),
      createdAt: Value(DateTime.now()),
    ));

    for (final t in detail.tracks) {
      await _ct.upsertTrack(TracksCompanion(
        id: Value(t.trackId),
        name: Value(t.name),
        artistId: Value(detail.id), // placeholder
        albumId: Value(detail.id),
        isrc: Value(t.isrc),
        durationMs: Value(t.durationMs),
        trackNumber: Value(t.trackNumber),
        coverUrl: Value(t.coverUrl ?? ''),
        coverPath: Value(t.coverPath ?? ''),
        source: Value(t.provider ?? source ?? ''),
        createdAt: Value(DateTime.now()),
      ));
    }
  }

  // ── Playlist Detail (local Drift) ──────────────────────────────

  /// Build a PlaylistDetail from local Drift data, or null if collection not found.
  Future<PlaylistDetail?> getPlaylistDetailLocal(String collectionId) async {
    final collection = await _cl.get(collectionId);
    if (collection == null) return null;

    final items = await _cl.getTracks(collectionId);
    final tracks = <DetailTrack>[];
    for (final item in items) {
      final trackId = item.trackId ?? item.itemId;
      final track = await _ct.getTrack(trackId);
      if (track != null) {
        tracks.add(DetailTrack(
          trackId: track.id,
          name: track.name,
          durationMs: track.durationMs ?? 0,
          trackNumber: track.trackNumber ?? 0,
          isrc: track.isrc ?? '',
          coverUrl: track.coverUrl,
          coverPath: track.coverPath,
          provider: track.source,
        ));
      }
    }

    return PlaylistDetail(
      id: collection.id,
      name: collection.name,
      coverPath: collection.coverPath,
      createdAt: collection.createdAt.toIso8601String(),
      updatedAt: collection.updatedAt.toIso8601String(),
      itemCount: tracks.length,
      tracks: tracks,
    );
  }

  /// Save extension-fetched playlist detail to local Drift tables.
  Future<void> syncPlaylistDetail(PlaylistDetail detail, {String? source}) async {
    // Upsert collection (playlist) with the actual ID so getPlaylistDetailLocal finds it
    await _cl.upsert(CollectionsCompanion(
      id: Value(detail.id),
      name: Value(detail.name),
      coverPath: Value(detail.coverPath ?? ''),
      type: const Value('playlist'),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));

    // Upsert tracks and add as collection items
    for (int i = 0; i < detail.tracks.length; i++) {
      final t = detail.tracks[i];
      await _ct.upsertTrack(TracksCompanion(
        id: Value(t.trackId),
        name: Value(t.name),
        artistId: Value(t.trackId), // placeholder
        isrc: Value(t.isrc),
        durationMs: Value(t.durationMs),
        trackNumber: Value(t.trackNumber),
        coverUrl: Value(t.coverUrl ?? ''),
        coverPath: Value(t.coverPath ?? ''),
        source: Value(t.provider ?? source ?? ''),
        createdAt: Value(DateTime.now()),
      ));
      await _cl.addTrack(detail.id, t.trackId);
    }
  }

  /// Save extension-fetched artist detail data to local Drift tables.
  /// Called after successful fetchArtistDetail to populate the local cache.
  Future<void> syncArtistDetail(ArtistDetail detail, {String? source}) async {
    await _ct.upsertArtist(ArtistsCompanion(
      id: Value(detail.id),
      name: Value(detail.name),
      normalizedName: Value(detail.name.trim().toLowerCase()),
      imageUrl: Value(detail.imageUrl ?? ''),
      imagePath: Value(detail.imagePath ?? ''),
      provider: Value(source ?? ''),
      createdAt: Value(DateTime.now()),
    ));

    for (final t in detail.topTracks) {
      await _ct.upsertTrack(TracksCompanion(
        id: Value(t.trackId),
        name: Value(t.name),
        artistId: Value(detail.id),
        isrc: Value(t.isrc),
        durationMs: Value(t.durationMs),
        trackNumber: Value(t.trackNumber),
        coverUrl: Value(t.coverUrl ?? ''),
        coverPath: Value(t.coverPath ?? ''),
        source: Value(t.provider ?? source ?? ''),
        createdAt: Value(DateTime.now()),
      ));
    }

    for (final a in detail.topAlbums) {
      await _ct.upsertAlbum(AlbumsCompanion(
        id: Value(a.albumId),
        name: Value(a.name),
        normalizedName: Value(a.name.trim().toLowerCase()),
        artistId: Value(detail.id),
        coverUrl: Value(a.coverUrl ?? ''),
        coverPath: Value(a.coverPath ?? ''),
        releaseDate: Value(a.releaseDate ?? ''),
        totalTracks: Value(a.totalTracks),
        provider: Value(source ?? ''),
        createdAt: Value(DateTime.now()),
      ));
    }
  }
}



