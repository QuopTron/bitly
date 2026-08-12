import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart' show Value;
import '../../injection.dart' as inj;
import '../rpc/backend_service.dart';
import '../../frontend/shared/models/feed_models.dart';
import '../../frontend/shared/models/detail_models.dart';
import '../cache/detail_cache.dart';
import '../cache/favorite_cache.dart';
import '../cache/playback_cache.dart';
import '../database/daos/download_dao.dart';
import '../database/daos/content_dao.dart';
import '../database/app_database.dart';
import 'item_fingerprint.dart';
import '../cache/like_state.dart';

mixin LikeActions on Cubit<LikeState> {
  BackendService get backend;
  FavoriteCache get _fav => inj.sl<FavoriteCache>();
  PlaybackCache get _pb => inj.sl<PlaybackCache>();
  DownloadDao? _dlDao;
  DownloadDao get _downloadDao => _dlDao ??= DownloadDao(inj.sl<AppDatabase>());
  ContentDao? _ctDao;
  ContentDao get _contentDao => _ctDao ??= ContentDao(inj.sl<AppDatabase>());

  String? _fingerprintForType(LikedItemData item) {
    final feedItem = FeedItem(
      id: item.id, type: item.type, name: item.name,
      artists: item.artists, coverUrl: item.coverUrl,
      albumName: item.albumName, durationMs: item.durationMs,
      isrc: item.isrc, source: item.source,
    );
    return fingerprintItem(feedItem);
  }

  Future<void> toggleLike(FeedItem item) async {
    final fp = fingerprintItem(item);
    final wasLiked = state.likedFingerprints.contains(fp);
    if (wasLiked) {
      await _unlike(item, fp);
    } else {
      await _like(item, fp);
    }
  }

  /// Saves the cover through the backend and returns its absolute local path
  /// (already usable by Image.file on every platform, Android included).
  Future<String?> _saveCover(String coverUrl) async {
    final path = await backend.saveCover(coverUrl);
    if (path != null && path.isNotEmpty) return path;
    return null;
  }

  Future<void> _like(FeedItem item, String fp) async {
    String? coverPath;
    if (item.coverUrl != null && item.coverUrl!.isNotEmpty) {
      if (item.type == 'track') {
        final localCover = await backend.getCoverPathForTrack(
          trackId: item.id,
          isrc: item.isrc,
          trackName: item.name,
          artistName: item.artists,
          coverUrl: item.coverUrl,
        );
        if (localCover != null && localCover.isNotEmpty) {
          coverPath = localCover;
        } else {
          coverPath = await _saveCover(item.coverUrl!);
        }
      } else {
        coverPath = await _saveCover(item.coverUrl!);
      }
    }

    final newFps = Set<String>.from(state.likedFingerprints)..add(fp);
    final newItems = Map<String, LikedItemData>.from(state.allLiked);
    newItems[item.id] = LikedItemData(
      id: item.id, type: item.type, name: item.name,
      artists: item.artists, coverUrl: item.coverUrl,
      localCoverPath: coverPath, source: item.source,
      albumName: item.albumName, durationMs: item.durationMs,
      isrc: item.isrc,
    );

    emit(state.copyWith(likedFingerprints: newFps, allLiked: newItems));

    _invalidateDetailCache(item.id, item.type);

    switch (item.type) {
      case 'track':
        unawaited(_fav.toggleLovedTrack(
          trackId: item.id, trackName: item.name,
          artistName: item.artists ?? '', albumName: item.albumName,
          coverUrl: item.coverUrl, coverPath: coverPath,
          isrc: item.isrc, durationMs: item.durationMs,
          liked: true, source: item.source,
        ));
      case 'album':
        unawaited(_fav.toggleFavoriteAlbum(
          albumId: item.id, name: item.name,
          artistId: item.artists ?? '', artistName: item.artists ?? '',
          coverUrl: item.coverUrl ?? '', coverPath: coverPath,
          liked: true, provider: item.source,
        ));
        // Fetch album detail and sync tracks + covers
        unawaited(_syncAlbumTracks(item.id, item.source ?? '', item.artists ?? '',
          parentCoverUrl: item.coverUrl,
        ));
      case 'artist':
        unawaited(_fav.toggleFavoriteArtist(
          artistId: item.id, name: item.name,
          imageUrl: item.coverUrl ?? '', imagePath: coverPath,
          liked: true,
        ));
      case 'playlist':
        unawaited(_fav.toggleFavoritePlaylist(
          playlistId: item.id, name: item.name,
          coverUrl: item.coverUrl, coverPath: coverPath,
          provider: item.source, liked: true,
        ));
        // Fetch playlist detail and sync tracks + covers
        unawaited(_syncPlaylistTracks(item.id, item.source ?? '',
          parentCoverUrl: item.coverUrl,
        ));
    }
  }

  /// Fetches album detail from Go backend and saves all tracks
  /// with their covers to the content database.
  Future<void> _syncAlbumTracks(String albumId, String source, String artistName, {String? parentCoverUrl}) async {
    String? syncedCover;
    try {
      final json = await backend.fetchAlbumDetail(albumId, source);
      if (json.isEmpty || json == '{}') return;
      final detail = AlbumDetail.fromJson(jsonDecode(json) as Map<String, dynamic>);
      await _pb.syncAlbumDetail(detail, source: source);
      for (final t in detail.tracks) {
        final cover = t.coverUrl?.isNotEmpty == true ? t.coverUrl : parentCoverUrl;
        if (cover != null && cover.isNotEmpty) {
          final path = await _saveCover(cover);
          if (path != null) {
            syncedCover ??= path;
            await _contentDao.upsertTrack(TracksCompanion(
              id: Value(t.trackId),
              name: Value(t.name),
              artistId: Value(t.trackId),
              coverPath: Value(path),
              durationMs: Value(t.durationMs),
              trackNumber: Value(t.trackNumber),
              isrc: Value(t.isrc),
              source: Value(t.provider ?? source),
              createdAt: Value(DateTime.now()),
            ));
          }
        }
      }
    } catch (_) {}
    _backfillLocalCover(albumId, syncedCover);
  }

  /// Fetches playlist detail from Go backend and saves all tracks
  /// with their covers to the content database.
  Future<void> _syncPlaylistTracks(String playlistId, String source, {String? parentCoverUrl}) async {
    String? syncedCover;
    try {
      final json = await backend.fetchPlaylistDetail(playlistId, source);
      if (json.isEmpty || json == '{}') return;
      final detail = PlaylistDetail.fromJson(jsonDecode(json) as Map<String, dynamic>);
      await _pb.syncPlaylistDetail(detail, source: source);
      for (final t in detail.tracks) {
        final cover = t.coverUrl?.isNotEmpty == true ? t.coverUrl : parentCoverUrl;
        if (cover != null && cover.isNotEmpty) {
          final path = await _saveCover(cover);
          if (path != null) {
            syncedCover ??= path;
            await _contentDao.upsertTrack(TracksCompanion(
              id: Value(t.trackId),
              name: Value(t.name),
              artistId: Value(t.trackId),
              coverPath: Value(path),
              durationMs: Value(t.durationMs),
              trackNumber: Value(t.trackNumber),
              isrc: Value(t.isrc),
              source: Value(t.provider ?? source),
              createdAt: Value(DateTime.now()),
            ));
          }
        }
      }
    } catch (_) {}
    _backfillLocalCover(playlistId, syncedCover);
  }

  /// If the parent album/playlist like didn't get a local cover (e.g. its
  /// initial saveCover failed), adopt the first successfully-synced track
  /// cover so the album/playlist grid card shows a local cover instead of gray.
  void _backfillLocalCover(String id, String? coverPath) {
    if (coverPath == null || coverPath.isEmpty) return;
    final cur = state.allLiked[id];
    if (cur == null || (cur.localCoverPath?.isNotEmpty == true)) return;
    final newItems = Map<String, LikedItemData>.from(state.allLiked);
    newItems[id] = cur.copyWith(localCoverPath: coverPath);
    emit(state.copyWith(allLiked: newItems));
  }

  Future<void> _unlike(FeedItem item, String fp) async {
    if (item.coverUrl != null && item.coverUrl!.isNotEmpty) {
      // Only delete cover if track is NOT downloaded
      if (!await _isTrackDownloaded(item)) {
        unawaited(backend.deleteCover(item.coverUrl!));
      }
    }

    final deadFps = <String>{fp};
    final existing = _likedItemByFingerprint(item);
    if (existing != null) {
      final efp = _fingerprintForType(existing);
      if (efp != null && efp != fp) deadFps.add(efp);
    }

    final newFps = Set<String>.from(state.likedFingerprints)
      ..removeAll(deadFps);
    final newItems = Map<String, LikedItemData>.from(state.allLiked)
      ..remove(item.id);

    emit(state.copyWith(likedFingerprints: newFps, allLiked: newItems));

    _invalidateDetailCache(item.id, item.type);

    switch (item.type) {
      case 'track':
        unawaited(_fav.toggleLovedTrack(
          trackId: item.id, trackName: item.name,
          artistName: item.artists ?? '', liked: false,
        ));
      case 'album':
        unawaited(_fav.toggleFavoriteAlbum(
          albumId: item.id, name: item.name,
          artistId: item.artists ?? '', artistName: item.artists ?? '',
          coverUrl: item.coverUrl ?? '', liked: false,
        ));
      case 'artist':
        unawaited(_fav.toggleFavoriteArtist(
          artistId: item.id, name: item.name,
          imageUrl: item.coverUrl ?? '', liked: false,
        ));
      case 'playlist':
        unawaited(_fav.toggleFavoritePlaylist(
          playlistId: item.id, name: item.name,
          coverUrl: item.coverUrl, liked: false,
        ));
    }
  }

  /// Checks if a track has been downloaded (exists in download history).
  Future<bool> _isTrackDownloaded(FeedItem item) async {
    try {
        final existing = await _downloadDao.findExisting(
        isrc: item.isrc,
        trackName: item.name,
        artistName: item.artists,
      );
      return existing.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> unlikeById(String id, String type, String name, String? artists, String? coverUrl) async {
    final fp = _fingerprintForType(LikedItemData(id: id, type: type, name: name, artists: artists));

    // Use original coverUrl from liked state (not resolved local path)
    final likedItem = state.allLiked[id];
    final originalCoverUrl = likedItem?.coverUrl ?? coverUrl;

    if (originalCoverUrl != null && originalCoverUrl.isNotEmpty) {
      if (type == 'track') {
        // Match the same check as _isTrackDownloaded: use isrc from state
        final existing = await _downloadDao.findExisting(
          isrc: likedItem?.isrc,
          trackName: name, artistName: artists,
        );
        if (existing.isEmpty) {
          unawaited(backend.deleteCover(originalCoverUrl));
        }
      } else {
        unawaited(backend.deleteCover(originalCoverUrl));
      }
    }

    final newFps = Set<String>.from(state.likedFingerprints);
    if (fp != null) newFps.remove(fp);
    final existing = state.allLiked[id];
    if (existing != null) {
      final efp = _fingerprintForType(existing);
      if (efp != null && efp != fp) newFps.remove(efp);
    }
    final newItems = Map<String, LikedItemData>.from(state.allLiked)..remove(id);

    emit(state.copyWith(likedFingerprints: newFps, allLiked: newItems));

    _invalidateDetailCache(id, type);

    switch (type) {
      case 'track':
        unawaited(_fav.toggleLovedTrack(
          trackId: id, trackName: name, artistName: artists ?? '', liked: false,
        ));
      case 'album':
        unawaited(_fav.toggleFavoriteAlbum(
          albumId: id, name: name, artistId: artists ?? '',
          artistName: artists ?? '', coverUrl: coverUrl ?? '', liked: false,
        ));
      case 'artist':
        unawaited(_fav.toggleFavoriteArtist(
          artistId: id, name: name, imageUrl: coverUrl ?? '', liked: false,
        ));
      case 'playlist':
        unawaited(_fav.toggleFavoritePlaylist(
          playlistId: id, name: name, liked: false,
        ));
    }
  }

  LikedItemData? _likedItemByFingerprint(FeedItem item) {
    final fp = fingerprintItem(item);
    return state.allLiked.values.where((v) {
      final vfp = _fingerprintForType(v);
      return vfp == fp;
    }).firstOrNull;
  }

  // ── DetailCache invalidation ─────────────────────────────────────

  void _invalidateDetailCache(String id, String type) {
    final cache = inj.sl<DetailCache>();
    unawaited(cache.invalidateUserStats());
    switch (type) {
      case 'album':
        unawaited(cache.invalidateAlbum(id));
      case 'artist':
        unawaited(cache.invalidateArtist(id));
      case 'playlist':
        unawaited(cache.invalidatePlaylist(id));
      case 'track':
        // No album/playlist ID available, only userStats is invalidated.
        break;
    }
  }
}




