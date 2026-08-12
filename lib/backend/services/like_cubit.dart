export '../cache/like_state.dart';

import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../injection.dart' as inj;
import '../rpc/backend_service.dart';
import '../../frontend/shared/models/feed_models.dart';
import '../cache/favorite_cache.dart';
import 'item_fingerprint.dart';
import '../cache/like_state.dart';
import 'like_actions.dart';

class LikeCubit extends Cubit<LikeState> with LikeActions {
  @override
  final BackendService backend;
  late final FavoriteCache _fav;
  bool _initialized = false;

  LikeCubit(this.backend) : super(const LikeState()) {
    _fav = inj.sl<FavoriteCache>();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    emit(state.copyWith(loading: true));
    try {
      final fingerprints = <String>{};
      final items = <String, LikedItemData>{};

      final tracksJson = await _fav.getLovedTracks();
      if (tracksJson.isNotEmpty && tracksJson != '[]') {
        final list = jsonDecode(tracksJson) as List;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final id = (m['trackId'] ?? m['track_id'] ?? '').toString();
          items[id] = LikedItemData(
            id: id, type: 'track',
            name: (m['trackName'] ?? m['track_name'] ?? '') as String,
            artists: (m['artistName'] ?? m['artist_name'] ?? '') as String,
            coverUrl: (m['coverUrl'] ?? m['cover_url'] ?? '') as String,
            localCoverPath: cleanLocalCoverPath(m['coverPath'] as String?),
            albumName: (m['albumName'] ?? m['album_name'] ?? '') as String,
            durationMs: (m['durationMs'] ?? m['duration_ms']) as int?,
            isrc: m['isrc'] as String?,
            source: (m['provider'] ?? '') as String?,
          );
        }
      }

      final albumsJson = await _fav.getFavoriteAlbums();
      if (albumsJson.isNotEmpty && albumsJson != '[]') {
        final list = jsonDecode(albumsJson) as List;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final id = (m['albumId'] ?? m['album_id'] ?? '').toString();
          items[id] = LikedItemData(
            id: id, type: 'album',
            name: (m['name'] ?? '') as String,
            artists: (m['artistName'] ?? m['artist_name'] ?? '') as String,
            coverUrl: (m['coverUrl'] ?? m['cover_url'] ?? '') as String,
            localCoverPath: cleanLocalCoverPath(m['coverPath'] as String?),
            source: (m['provider'] ?? '') as String?,
          );
        }
      }

      final artistsJson = await _fav.getFavoriteArtists();
      if (artistsJson.isNotEmpty && artistsJson != '[]') {
        final list = jsonDecode(artistsJson) as List;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final id = (m['artistId'] ?? m['artist_id'] ?? '').toString();
          items[id] = LikedItemData(
            id: id, type: 'artist',
            name: (m['name'] ?? '') as String,
            coverUrl: (m['imageUrl'] ?? m['image_url'] ?? '') as String,
            localCoverPath: cleanLocalCoverPath(m['imagePath'] as String?),
          );
        }
      }

      final playlistsJson = await _fav.getLikedPlaylists();
      if (playlistsJson.isNotEmpty && playlistsJson != '[]') {
        final list = jsonDecode(playlistsJson) as List;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final id = (m['playlistId'] ?? m['playlist_id'] ?? '').toString();
          items[id] = LikedItemData(
            id: id, type: 'playlist',
            name: (m['name'] ?? '') as String,
            coverUrl: (m['coverUrl'] ?? m['cover_url'] ?? '') as String,
            localCoverPath: cleanLocalCoverPath(m['coverPath'] as String?),
            source: (m['provider'] ?? '') as String?,
          );
        }
      }

      for (final item in items.values) {
        final feedItem = FeedItem(
          id: item.id, type: item.type, name: item.name,
          artists: item.artists, coverUrl: item.coverUrl,
          albumName: item.albumName, durationMs: item.durationMs,
          isrc: item.isrc, source: item.source,
        );
        final fp = fingerprintItem(feedItem);
        fingerprints.add(fp);
      }

      emit(state.copyWith(
        likedFingerprints: fingerprints,
        allLiked: items,
        loading: false,
      ));
      _initialized = true;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  bool isLiked(FeedItem item) {
    final fp = fingerprintItem(item);
    return state.likedFingerprints.contains(fp);
  }

  bool isItemIdLiked(String id) => state.allLiked.containsKey(id);

  LikedItemData? likedItemById(String id) => state.allLiked[id];

  String? localCoverFor(FeedItem item) {
    final fp = fingerprintItem(item);
    final matched = state.allLiked.values.where((v) {
      final feedItem = FeedItem(
        id: v.id, type: v.type, name: v.name,
        artists: v.artists, coverUrl: v.coverUrl,
        albumName: v.albumName, durationMs: v.durationMs,
        isrc: v.isrc, source: v.source,
      );
      return fingerprintItem(feedItem) == fp;
    }).firstOrNull;
    return cleanLocalCoverPath(matched?.localCoverPath);
  }

  /// Resolves the best cover URL for a FeedItem:
  /// local cover path (if liked) → network coverUrl (original).
  /// Use this everywhere instead of raw [FeedItem.coverUrl] to
  /// ensure liked items show their locally cached covers.
  String? resolveCoverFor(FeedItem item) => localCoverFor(item) ?? item.coverUrl;

  List<LikedItemData> get tracks =>
      state.allLiked.values.where((i) => i.type == 'track').toList();

  List<LikedItemData> get albums =>
      state.allLiked.values.where((i) => i.type == 'album').toList();

  List<LikedItemData> get artists =>
      state.allLiked.values.where((i) => i.type == 'artist').toList();

  int get tracksCount => tracks.length;
  int get albumsCount => albums.length;
  int get artistsCount => artists.length;
}




