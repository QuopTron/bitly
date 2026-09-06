import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart' show Value;
import '../../injection.dart' as inj;
import '../rpc/backend_service.dart';
import '../../frontend/shared/models/feed_models.dart';
import '../../frontend/shared/models/detail_models.dart';
import '../../frontend/shared/utils/download_strategy.dart';
import '../cache/detail_cache.dart';
import '../cache/favorite_cache.dart';
import '../cache/playback_cache.dart';
import '../database/daos/download_dao.dart';
import '../database/daos/content_dao.dart';
import '../database/app_database.dart';
import 'item_fingerprint.dart';
import '../cache/like_state.dart';
import 'download_cubit.dart';
import 'package:bitly/frontend/shared/utils/download_strategy.dart' show normalizeTrackId;

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
    // Optimistic: pintar el corazón y persistir el like ANTES de tocar la red.
    // En Android el bridge serializa todos los RPC en un único hilo, así que un
    // RPC de cover encolado detrás de una descarga larga puede tardar decenas
    // de segundos o expirar. Esperarlo aquí retrasaría (o bloquearía) el emit
    // y el usuario vería el corazón sin pintar aunque el like sí se haya dado.
    final newFps = Set<String>.from(state.likedFingerprints)..add(fp);
    // El ISRC es el identificador que comparten TODAS las extensiones para la
    // misma grabación: sumarlo al set hace que el corazón de un track likeado
    // desde Deezer se refleje en el mismo track desde Spotify/Amazon/etc.
    if (item.type == 'track' && item.isrc != null && item.isrc!.isNotEmpty) {
      newFps.add(fingerprintIsrc(item.isrc!));
    }
    final newItems = Map<String, LikedItemData>.from(state.allLiked);
    newItems[item.id] = LikedItemData(
      id: item.id, type: item.type, name: item.name,
      artists: item.artists, coverUrl: item.coverUrl,
      source: item.source,
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
          coverUrl: item.coverUrl,
          isrc: item.isrc, durationMs: item.durationMs,
          liked: true, source: item.source,
        ));
      case 'album':
        unawaited(_fav.toggleFavoriteAlbum(
          albumId: item.id, name: item.name,
          artistId: item.artists ?? '', artistName: item.artists ?? '',
          coverUrl: item.coverUrl ?? '',
          liked: true, provider: item.source,
        ));
        // Fetch album detail and sync tracks + covers
        unawaited(_syncAlbumTracks(item.id, item.source ?? '', item.artists ?? '',
          parentCoverUrl: item.coverUrl,
        ));
      case 'artist':
        unawaited(_fav.toggleFavoriteArtist(
          artistId: item.id, name: item.name,
          imageUrl: item.coverUrl ?? '', liked: true,
        ));
      case 'playlist':
        unawaited(_fav.toggleFavoritePlaylist(
          playlistId: item.id, name: item.name,
          coverUrl: item.coverUrl,
          provider: item.source, liked: true,
        ));
        // Fetch playlist detail and sync tracks + covers
        unawaited(_syncPlaylistTracks(item.id, item.source ?? '',
          parentCoverUrl: item.coverUrl,
        ));
    }

    // Guardar la cover es best-effort y NO bloquea el like: corre en segundo
    // plano y, si obtiene un path local, lo agrega al estado (y a la fila de
    // favoritos) cuando esté disponible.
    unawaited(_saveCoverForLike(item, fp));
  }

  /// Downloads the cover for a freshly-liked [item] in the background and
  /// patches the local cover path into the state (and the loved-track row)
  /// once it's available. No-op if the item was unliked while saving, so a
  /// stale RPC can never resurrect a removed favorite's cover.
  Future<void> _saveCoverForLike(FeedItem item, String fp) async {
    String? coverPath;
    const maxRetries = 3;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (item.coverUrl == null || item.coverUrl!.isEmpty) break;
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
        if (coverPath != null && coverPath.isNotEmpty) break;
      } catch (_) {
        coverPath = null;
      }
      // Exponential backoff: 1s, 2s, 4s
      if (attempt < maxRetries - 1) {
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
    if (coverPath == null || coverPath.isEmpty) return;
    // Solo parcheamos si el item sigue likeado (pudo quitarse el like mientras
    // el RPC de cover estaba encolado).
    if (!state.likedFingerprints.contains(fp)) return;
    final cur = state.allLiked[item.id];
    if (cur == null || cur.localCoverPath?.isNotEmpty == true) return;
    final newItems = Map<String, LikedItemData>.from(state.allLiked);
    newItems[item.id] = cur.copyWith(localCoverPath: coverPath);
    emit(state.copyWith(allLiked: newItems));
    if (item.type == 'track') {
      // Persistir también el coverPath en la fila de favoritos (upsert) para
      // que sobreviva al reinicio.
      unawaited(_fav.toggleLovedTrack(
        trackId: item.id, trackName: item.name,
        artistName: item.artists ?? '', albumName: item.albumName,
        coverUrl: item.coverUrl, coverPath: coverPath,
        isrc: item.isrc, durationMs: item.durationMs,
        liked: true, source: item.source,
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
      // Solo borra la portada si nada la sigue mostrando: los tracks miran el
      // historial de descargas, y los álbumes/playlists miran si aún existe el
      // batch descargado (un like de un álbum descargado conserva su portada
      // en Mi Espacio aunque se quite el corazón).
      final stillNeeded = item.type == 'track'
          ? await _isTrackDownloaded(item)
          : await _isCollectionDownloaded(
              item.type, item.id, item.source ?? '');
      if (!stillNeeded) {
        unawaited(backend.deleteCover(item.coverUrl!));
      }
    }

    final deadFps = <String>{fp};
    // Quitar también el fingerprint por ISRC para que el corazón se apague en
    // TODAS las extensiones donde aparezca la misma grabación.
    if (item.type == 'track' && item.isrc != null && item.isrc!.isNotEmpty) {
      deadFps.add(fingerprintIsrc(item.isrc!));
    }
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

  /// Checks if a track has been downloaded. Uses DownloadCubit's in-memory
  /// state (source-agnostic, matches by normalized ID) which is more reliable
  /// than the DB lookup that depends on exact name/artist match.
  Future<bool> _isTrackDownloaded(FeedItem item) async {
    try {
      final dlCubit = inj.sl<DownloadCubit>();
      final normId = normalizeTrackId(item.id);
      // Check any completed track entry with this normalized ID, regardless of source
      for (final entry in dlCubit.state.downloads.entries) {
        if (entry.value.state != DownloadState.completed) continue;
        if (!entry.key.startsWith('track_')) continue;
        // entry.key format: track_{normalizedId}_{source}
        final parts = entry.key.split('_');
        if (parts.length >= 3) {
          final entryNormId = parts.sublist(1, parts.length - 1).join('_');
          if (entryNormId == normId) return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// True when the album/playlist [type] [id] still has a downloaded batch
  /// (its cover is still shown in Mi Espacio). Retries with an empty source
  /// because the batch may be stored under a different extension name.
  Future<bool> _isCollectionDownloaded(
    String type, String id, String source,
  ) async {
    try {
      // Fast path: check DownloadCubit's in-memory state first (most reliable,
      // covers source mismatches and after-restart restoration).
      final dlCubit = inj.sl<DownloadCubit>();
      if (dlCubit.isCollectionDownloaded(type, id)) return true;
      // Fallback: check DB batches (handles edge cases where in-memory state
      // was cleared but DB still has the batch).
      final normalized = normalizeTrackId(id);
      var batch = await _downloadDao.getBatchByItem(type, normalized, source);
      if (batch == null && source.isNotEmpty) {
        batch = await _downloadDao.getBatchByItem(type, normalized, '');
      }
      return batch != null;
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
        // Use the same in-memory check as _isTrackDownloaded
        final dlCubit = inj.sl<DownloadCubit>();
        final normId = normalizeTrackId(id);
        bool found = false;
        for (final entry in dlCubit.state.downloads.entries) {
          if (entry.value.state != DownloadState.completed) continue;
          if (!entry.key.startsWith('track_')) continue;
          final parts = entry.key.split('_');
          if (parts.length >= 3) {
            final entryNormId = parts.sublist(1, parts.length - 1).join('_');
            if (entryNormId == normId) { found = true; break; }
          }
        }
        if (!found) {
          unawaited(backend.deleteCover(originalCoverUrl));
        }
      } else {
        // Álbum/playlist: conservar la portada si todavía hay un batch
        // descargado que la muestra en Mi Espacio.
        final stillDownloaded = await _isCollectionDownloaded(
          type, id, likedItem?.source ?? '');
        if (!stillDownloaded) {
          unawaited(backend.deleteCover(originalCoverUrl));
        }
      }
    }

    final newFps = Set<String>.from(state.likedFingerprints);
    if (fp != null) newFps.remove(fp);
    final existing = state.allLiked[id];
    if (existing != null) {
      final efp = _fingerprintForType(existing);
      if (efp != null && efp != fp) newFps.remove(efp);
      final isrc = existing.isrc;
      if (isrc != null && isrc.isNotEmpty) newFps.remove(fingerprintIsrc(isrc));
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




