import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import '../database/app_database.dart';
import '../database/daos/favorites_dao.dart';

/// Favorites (loved tracks, albums, artists, playlists) local cache.
class FavoriteCache {
  final FavoritesDao _f;
  FavoriteCache(AppDatabase db)
      : _f = FavoritesDao(db);

  // ── Loved Tracks ────────────────────────────────────────────────

  Future<bool> isTrackLoved(String trackId) => _f.isLoved(trackId);

  Future<String> getLovedTracks() async {
    final items = await _f.getLovedTracks();
    final list = items.map((e) => <String, dynamic>{
      'trackId': e.trackId, 'trackName': e.trackName,
      'artistName': e.artistName, 'albumName': e.albumName ?? '',
      'coverUrl': e.coverUrl ?? '', 'coverPath': e.coverPath ?? '',
      'isrc': e.isrc ?? '', 'durationMs': e.durationMs ?? 0,
      'provider': e.provider ?? '',
      'addedAt': e.addedAt.toIso8601String(),
      'track_id': e.trackId, 'track_name': e.trackName,
      'artist_name': e.artistName, 'album_name': e.albumName ?? '',
      'cover_url': e.coverUrl ?? '', 'duration_ms': e.durationMs ?? 0,
    }).toList();
    return jsonEncode(list);
  }

  Future<void> toggleLovedTrack({
    required String trackId, required String trackName,
    required String artistName, String? albumName,
    String? coverUrl, String? coverPath, String? isrc,
    int? durationMs, bool liked = true, String? source,
  }) async {
    if (liked) {
      await _f.addLovedTrack(trackId: trackId, trackName: trackName,
        artistName: artistName, albumName: albumName, coverUrl: coverUrl,
        coverPath: coverPath, isrc: isrc, durationMs: durationMs, source: source);
    } else {
      await _f.removeLovedTrack(trackId);
    }
  }

  // ── Favorite Albums ─────────────────────────────────────────────

  Future<String> getFavoriteAlbums() async {
    final items = await _f.getFavoriteAlbums();
    final list = items.map((e) => <String, dynamic>{
      'albumId': e.albumId, 'name': e.name,
      'artistId': e.artistId, 'artistName': e.artistName,
      'coverUrl': e.coverUrl, 'coverPath': e.coverPath ?? '',
      'provider': e.provider ?? '',
      'addedAt': e.addedAt.toIso8601String(),
      'album_id': e.albumId, 'artist_name': e.artistName,
      'cover_url': e.coverUrl,
    }).toList();
    return jsonEncode(list);
  }

  Future<void> toggleFavoriteAlbum({
    required String albumId, required String name,
    required String artistId, required String artistName,
    required String coverUrl, String? coverPath,
    String? provider, bool liked = true,
  }) async {
    if (liked) {
      await _f.addFavoriteAlbum(albumId: albumId, name: name,
        artistId: artistId, artistName: artistName,
        coverUrl: coverUrl, coverPath: coverPath, provider: provider);
    } else {
      await _f.removeFavoriteAlbum(albumId);
    }
  }

  // ── Favorite Artists ────────────────────────────────────────────

  Future<String> getFavoriteArtists() async {
    final items = await _f.getFavoriteArtists();
    final list = items.map((e) => <String, dynamic>{
      'artistId': e.artistId, 'name': e.name,
      'imageUrl': e.imageUrl, 'imagePath': e.imagePath ?? '',
      'provider': e.provider ?? '',
      'addedAt': e.addedAt.toIso8601String(),
      'artist_id': e.artistId, 'image_url': e.imageUrl,
    }).toList();
    return jsonEncode(list);
  }

  Future<void> toggleFavoriteArtist({
    required String artistId, required String name,
    required String imageUrl, String? imagePath, bool liked = true,
  }) async {
    if (liked) {
      await _f.addFavoriteArtist(artistId: artistId, name: name,
        imageUrl: imageUrl, imagePath: imagePath);
    } else {
      await _f.removeFavoriteArtist(artistId);
    }
  }

  // ── Favorite Playlists ──────────────────────────────────────────

  Future<String> getFavoritePlaylists() async {
    final items = await _f.getFavoritePlaylists();
    final list = items.map((e) => <String, dynamic>{
      'playlistId': e.playlistId, 'name': e.name,
      'coverUrl': e.coverUrl ?? '', 'coverPath': e.coverPath ?? '',
      'description': e.description ?? '', 'provider': e.provider ?? '',
      'externalUrl': e.externalUrl ?? '',
      'addedAt': e.addedAt.toIso8601String(),
      'playlist_id': e.playlistId, 'cover_url': e.coverUrl ?? '',
    }).toList();
    return jsonEncode(list);
  }

  Future<String> getLikedPlaylists() => getFavoritePlaylists();

  Future<void> toggleFavoritePlaylist({
    required String playlistId, required String name,
    String? coverUrl, String? coverPath, String? provider,
    String? description, String? externalUrl, bool liked = true,
  }) async {
    if (liked) {
      await _f.addFavoritePlaylist(FavoritePlaylistsCompanion(
        playlistId: Value(playlistId), name: Value(name),
        coverUrl: Value(coverUrl ?? ''), coverPath: Value(coverPath ?? ''),
        description: Value(description ?? ''),
        provider: Value(provider ?? ''),
        externalUrl: Value(externalUrl ?? ''),
        addedAt: Value(DateTime.now()),
      ));
    } else {
      await _f.removeFavoritePlaylist(playlistId);
    }
  }

}

