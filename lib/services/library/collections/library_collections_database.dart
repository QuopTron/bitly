/// Puente singleton hacia el backend Go para colecciones de la biblioteca.
/// Carga el snapshot completo de todas las colecciones (playlists,
/// wishlist, tracks amados, LibraryCollectionsFavorites). Las operaciones de playlists
/// están en [LibraryCollectionsPlaylists] y las de LibraryCollectionsFavorites en
/// [LibraryCollectionsFavorites].
library;

export 'package:bitly/services/library/collections/collection_models.dart';
export 'package:bitly/services/library/collections/library_collections_playlists.dart';
export 'package:bitly/services/library/collections/library_collections_favorites.dart';

import 'dart:convert';
import 'package:bitly/services/library/collections/collection_models.dart';
import 'package:bitly/services/library/collections/library_collections_favorites.dart';
import 'package:bitly/services/library/collections/library_collections_playlists.dart';
import 'package:bitly/services/utilities/database_utils.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';

final _collLog = AppLogger('CollDb');

class LibraryCollectionsDatabase {
  static final LibraryCollectionsDatabase instance = LibraryCollectionsDatabase._init();
  LibraryCollectionsDatabase._init();

  Future<LibraryCollectionsSnapshot> loadSnapshot() async {
    try {
      final result = await PlatformBridge.invoke('getAllCollections');
      final allCollections = _decodeJsonList(result);
      final playlists = allCollections?.where((c) => c['type'] == 'playlist').toList() ?? [];
      final wishlist = allCollections?.where((c) => c['type'] == 'wishlist').toList() ?? [];

      final lovedRowsResult = await PlatformBridge.invoke('getAllFavorites', {'type': 'loved_track'});
      final lovedRows = _decodeJsonList(lovedRowsResult) ?? [];

      final trackItemsResult = await PlatformBridge.invoke('getAllCollectionItems');
      final playlistTrackRows = _decodeJsonList(trackItemsResult) ?? [];

      final favArtistsResult = await PlatformBridge.invoke('getAllFavorites', {'type': 'artist'});
      final favoriteArtistRows = _decodeJsonList(favArtistsResult) ?? [];

      final favAlbumsResult = await PlatformBridge.invoke('getAllFavorites', {'type': 'album'});
      final favoriteAlbumRows = _decodeJsonList(favAlbumsResult) ?? [];

      final favPlaylistsResult = await PlatformBridge.invoke('getAllFavorites', {'type': 'playlist'});
      final favoritePlaylistRows = _decodeJsonList(favPlaylistsResult) ?? [];

      return LibraryCollectionsSnapshot(
        wishlistRows: wishlist, lovedRows: lovedRows,
        playlistRows: playlists, playlistTrackRows: playlistTrackRows,
        favoriteArtistRows: favoriteArtistRows, favoriteAlbumRows: favoriteAlbumRows,
        favoritePlaylistRows: favoritePlaylistRows,
      );
    } catch (e) {
      _collLog.w('Go loadSnapshot failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  List<Map<String, dynamic>>? _decodeJsonList(dynamic json) {
    if (json is! String || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    } catch (_) {}
    return null;
  }

  // -- Playlist delegates --
  Future<void> upsertPlaylist({required String id, required String name, required String createdAt, required String updatedAt, String? coverImagePath}) =>
      LibraryCollectionsPlaylists.instance.upsertPlaylist(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt, coverImagePath: coverImagePath);
  Future<void> deletePlaylist(String playlistId) => LibraryCollectionsPlaylists.instance.deletePlaylist(playlistId);
  Future<void> renamePlaylist({required String playlistId, required String name}) =>
      LibraryCollectionsPlaylists.instance.renamePlaylist(playlistId: playlistId, name: name);
  Future<void> updatePlaylistCover({required String playlistId, String? coverImagePath, String? updatedAt}) =>
      LibraryCollectionsPlaylists.instance.updatePlaylistCover(playlistId: playlistId, coverImagePath: coverImagePath, updatedAt: updatedAt);
  Future<void> upsertPlaylistTrack({required String playlistId, required String trackKey, required String trackJson, required String addedAt, required String playlistUpdatedAt}) =>
      LibraryCollectionsPlaylists.instance.upsertPlaylistTrack(playlistId: playlistId, trackKey: trackKey, trackJson: trackJson, addedAt: addedAt, playlistUpdatedAt: playlistUpdatedAt);
  Future<void> upsertPlaylistTracksBatch({required String playlistId, required List<Map<String, dynamic>> tracks, required String playlistUpdatedAt}) =>
      LibraryCollectionsPlaylists.instance.upsertPlaylistTracksBatch(playlistId: playlistId, tracks: tracks, playlistUpdatedAt: playlistUpdatedAt);
  Future<void> deletePlaylistTrack({required String playlistId, required String trackKey, required String playlistUpdatedAt}) =>
      LibraryCollectionsPlaylists.instance.deletePlaylistTrack(playlistId: playlistId, trackKey: trackKey, playlistUpdatedAt: playlistUpdatedAt);
  Future<void> updatePlaylistTrackPaths({required String playlistId, required String trackKey, required String trackJson, String? audioPath, String? coverPath, String? codec, int? bitDepth, int? sampleRate}) =>
      LibraryCollectionsPlaylists.instance.updatePlaylistTrackPaths(playlistId: playlistId, trackKey: trackKey, trackJson: trackJson, audioPath: audioPath, coverPath: coverPath, codec: codec, bitDepth: bitDepth, sampleRate: sampleRate);
  Future<List<({String playlistId, String trackKey})>> getPlaylistTracksByCanonicalKey(String canonicalKey) =>
      LibraryCollectionsPlaylists.instance.getPlaylistTracksByCanonicalKey(canonicalKey);
  Future<List<PlaylistPickerSummaryRow>> loadPlaylistPickerSummaries(List<String> keys) =>
      LibraryCollectionsPlaylists.instance.loadPlaylistPickerSummaries(keys);

  // -- Favorite delegates --
  Future<void> upsertLovedEntry({required String trackKey, required String trackJson, required String addedAt, String? matchKey, String? audioPath, String? coverPath, String? codec, int? bitDepth, int? sampleRate}) =>
      LibraryCollectionsFavorites.instance.upsertLovedEntry(trackKey: trackKey, trackJson: trackJson, addedAt: addedAt, matchKey: matchKey, audioPath: audioPath, coverPath: coverPath, codec: codec, bitDepth: bitDepth, sampleRate: sampleRate);
  Future<void> deleteLovedEntry(String trackKey) => LibraryCollectionsFavorites.instance.deleteLovedEntry(trackKey);
  Future<void> upsertWishlistEntry({required String trackKey, required String trackJson, required String addedAt, String? matchKey}) =>
      LibraryCollectionsFavorites.instance.upsertWishlistEntry(trackKey: trackKey, trackJson: trackJson, addedAt: addedAt, matchKey: matchKey);
  Future<void> deleteWishlistEntry(String trackKey) => LibraryCollectionsFavorites.instance.deleteWishlistEntry(trackKey);
  Future<void> upsertFavoriteArtistEntry({required String artistKey, required String artistJson, required String addedAt, String? coverPath}) =>
      LibraryCollectionsFavorites.instance.upsertFavoriteArtistEntry(artistKey: artistKey, artistJson: artistJson, addedAt: addedAt, coverPath: coverPath);
  Future<void> deleteFavoriteArtistEntry(String artistKey) => LibraryCollectionsFavorites.instance.deleteFavoriteArtistEntry(artistKey);
  Future<void> upsertFavoriteAlbumEntry({required String albumKey, required String albumJson, required String addedAt, String? coverPath}) =>
      LibraryCollectionsFavorites.instance.upsertFavoriteAlbumEntry(albumKey: albumKey, albumJson: albumJson, addedAt: addedAt, coverPath: coverPath);
  Future<void> deleteFavoriteAlbumEntry(String albumKey) => LibraryCollectionsFavorites.instance.deleteFavoriteAlbumEntry(albumKey);
  Future<void> upsertFavoritePlaylistEntry({required String playlistKey, required String playlistJson, required String addedAt, String? coverPath}) =>
      LibraryCollectionsFavorites.instance.upsertFavoritePlaylistEntry(playlistKey: playlistKey, playlistJson: playlistJson, addedAt: addedAt, coverPath: coverPath);
  Future<void> deleteFavoritePlaylistEntry(String playlistId) => LibraryCollectionsFavorites.instance.deleteFavoritePlaylistEntry(playlistId);
  Future<void> updateLovedTrackPathsByCanonicalKey({required String canonicalKey, required String trackJson, String? audioPath, String? coverPath, String? codec, int? bitDepth, int? sampleRate, int? bitrate, int? duration, int? trackNumber, int? totalTracks, int? discNumber, int? totalDiscs}) =>
      LibraryCollectionsFavorites.instance.updateLovedTrackPathsByCanonicalKey(canonicalKey: canonicalKey, trackJson: trackJson, audioPath: audioPath, coverPath: coverPath, codec: codec, bitDepth: bitDepth, sampleRate: sampleRate, bitrate: bitrate, duration: duration, trackNumber: trackNumber, totalTracks: totalTracks, discNumber: discNumber, totalDiscs: totalDiscs);
}
