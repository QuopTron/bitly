/// Operaciones de LibraryCollectionsFavorites para colecciones de la biblioteca local.
/// Gestiona tracks amados, wishlist y LibraryCollectionsFavorites de artistas, álbumes
/// y playlists a través del backend Go.
library;

import 'dart:convert';
import 'package:bitly/services/utilities/database_utils.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';

final _favLog = AppLogger('CollFav');

class LibraryCollectionsFavorites {
  static final LibraryCollectionsFavorites instance = LibraryCollectionsFavorites._init();
  LibraryCollectionsFavorites._init();

  Future<void> upsertLovedEntry({
    required String trackKey, required String trackJson, required String addedAt,
    String? matchKey, String? audioPath, String? coverPath,
    String? codec, int? bitDepth, int? sampleRate,
  }) async {
    try {
      await PlatformBridge.invoke('upsertFavorite', jsonEncode({
        'item_id': trackKey, 'type': 'loved_track', 'name': trackKey,
        'item_json': trackJson, 'added_at': addedAt, 'match_key': matchKey,
        'audio_path': audioPath, 'cover_path': coverPath,
        'codec': codec, 'bit_depth': bitDepth, 'sample_rate': sampleRate,
      }));
    } catch (e) {
      _favLog.w('Go upsertLovedEntry failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<void> deleteLovedEntry(String trackKey) async {
    try { await PlatformBridge.invoke('deleteFavorite', trackKey); }
    catch (e) { _favLog.w('Go deleteLovedEntry failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> upsertWishlistEntry({
    required String trackKey, required String trackJson, required String addedAt,
    String? matchKey,
  }) async {
    try {
      await PlatformBridge.invoke('upsertCollection', jsonEncode({
        'id': 'wl_$trackKey', 'name': trackKey, 'type': 'wishlist',
        'item_json': trackJson, 'created_at': addedAt, 'updated_at': addedAt,
      }));
    } catch (e) { _favLog.w('Go upsertWishlistEntry failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> deleteWishlistEntry(String trackKey) async {
    try { await PlatformBridge.invoke('deleteCollection', 'wl_$trackKey'); }
    catch (e) { _favLog.w('Go deleteWishlistEntry failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> upsertFavoriteArtistEntry({
    required String artistKey, required String artistJson, required String addedAt,
    String? coverPath,
  }) async {
    try {
      await PlatformBridge.invoke('upsertFavorite', jsonEncode({
        'item_id': artistKey, 'type': 'artist', 'name': artistKey,
        'item_json': artistJson, 'cover_url': coverPath, 'added_at': addedAt,
      }));
    } catch (e) { _favLog.w('Go upsertFavoriteArtistEntry failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> deleteFavoriteArtistEntry(String artistKey) async {
    try { await PlatformBridge.invoke('deleteFavorite', artistKey); }
    catch (e) { _favLog.w('Go deleteFavoriteArtistEntry failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> upsertFavoriteAlbumEntry({
    required String albumKey, required String albumJson, required String addedAt,
    String? coverPath,
  }) async {
    try {
      await PlatformBridge.invoke('upsertFavorite', jsonEncode({
        'item_id': albumKey, 'type': 'album', 'name': albumKey,
        'item_json': albumJson, 'cover_url': coverPath, 'added_at': addedAt,
      }));
    } catch (e) { _favLog.w('Go upsertFavoriteAlbumEntry failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> deleteFavoriteAlbumEntry(String albumKey) async {
    try { await PlatformBridge.invoke('deleteFavorite', albumKey); }
    catch (e) { _favLog.w('Go deleteFavoriteAlbumEntry failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> upsertFavoritePlaylistEntry({
    required String playlistKey, required String playlistJson, required String addedAt,
    String? coverPath,
  }) async {
    try {
      await PlatformBridge.invoke('upsertFavorite', jsonEncode({
        'item_id': playlistKey, 'type': 'playlist', 'name': playlistKey,
        'item_json': playlistJson, 'cover_url': coverPath, 'added_at': addedAt,
      }));
    } catch (e) { _favLog.w('Go upsertFavoritePlaylistEntry failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> deleteFavoritePlaylistEntry(String playlistId) async {
    try { await PlatformBridge.invoke('deleteFavorite', playlistId); }
    catch (e) { _favLog.w('Go deleteFavoritePlaylistEntry failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> updateLovedTrackPathsByCanonicalKey({
    required String canonicalKey, required String trackJson,
    String? audioPath, String? coverPath, String? codec,
    int? bitDepth, int? sampleRate, int? bitrate, int? duration,
    int? trackNumber, int? totalTracks, int? discNumber, int? totalDiscs,
  }) async {
    // Shared update logic - currently a stub
  }
}
