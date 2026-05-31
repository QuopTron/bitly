/// Operaciones de playlists para colecciones de la biblioteca local.
/// Gestiona creación, eliminación, renombrado, portada y tracks de
/// playlists, así como la carga de resúmenes para el selector.
library;

import 'dart:convert';
import 'package:bitly/services/biblioteca/colecciones/modelos_colecciones.dart';
import 'package:bitly/services/utilidades/database_utils.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/utils/logger.dart';

final _plLog = AppLogger('CollPlaylists');

class LibraryCollectionsPlaylists {
  static final LibraryCollectionsPlaylists instance = LibraryCollectionsPlaylists._init();
  LibraryCollectionsPlaylists._init();

  Future<void> upsertPlaylist({
    required String id, required String name,
    required String createdAt, required String updatedAt,
    String? coverImagePath,
  }) async {
    try {
      await PlatformBridge.invoke('upsertCollection', jsonEncode({
        'id': id, 'name': name, 'type': 'playlist',
        'cover_path': coverImagePath, 'created_at': createdAt, 'updated_at': updatedAt,
      }));
    } catch (e) { _plLog.w('Go upsertPlaylist failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> deletePlaylist(String playlistId) async {
    try { await PlatformBridge.invoke('deleteCollection', playlistId); }
    catch (e) { _plLog.w('Go deletePlaylist failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> renamePlaylist({required String playlistId, required String name}) async {
    try {
      await PlatformBridge.invoke('upsertCollection', jsonEncode({
        'id': playlistId, 'name': name, 'type': 'playlist',
        'updated_at': DateTime.now().toIso8601String(),
      }));
    } catch (e) { _plLog.w('Go renamePlaylist failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> updatePlaylistCover({required String playlistId, String? coverImagePath, String? updatedAt}) async {
    try {
      await PlatformBridge.invoke('upsertCollection', jsonEncode({
        'id': playlistId, 'type': 'playlist', 'cover_path': coverImagePath,
        'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      }));
    } catch (e) { _plLog.w('Go updatePlaylistCover failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> upsertPlaylistTrack({
    required String playlistId, required String trackKey,
    required String trackJson, required String addedAt,
    required String playlistUpdatedAt,
  }) async {
    try {
      await PlatformBridge.invoke('addToCollection', {
        'collection_id': playlistId, 'item_id': trackKey,
        'added_at': addedAt, 'item_json': trackJson,
      });
      await PlatformBridge.invoke('upsertCollection', jsonEncode({
        'id': playlistId, 'type': 'playlist', 'updated_at': playlistUpdatedAt,
      }));
    } catch (e) { _plLog.w('Go upsertPlaylistTrack failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> upsertPlaylistTracksBatch({
    required String playlistId, required List<Map<String, dynamic>> tracks,
    required String playlistUpdatedAt,
  }) async {
    try {
      for (final track in tracks) {
        await upsertPlaylistTrack(
          playlistId: playlistId,
          trackKey: track['trackKey'], trackJson: track['trackJson'],
          addedAt: track['addedAt'], playlistUpdatedAt: playlistUpdatedAt,
        );
      }
    } catch (e) { _plLog.w('Go upsertPlaylistTracksBatch failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> deletePlaylistTrack({
    required String playlistId, required String trackKey,
    required String playlistUpdatedAt,
  }) async {
    try {
      await PlatformBridge.invoke('removeFromCollection', {
        'collection_id': playlistId, 'item_id': trackKey,
      });
      await PlatformBridge.invoke('upsertCollection', jsonEncode({
        'id': playlistId, 'type': 'playlist', 'updated_at': playlistUpdatedAt,
      }));
    } catch (e) { _plLog.w('Go deletePlaylistTrack failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> updatePlaylistTrackPaths({
    required String playlistId, required String trackKey,
    required String trackJson, String? audioPath, String? coverPath,
    String? codec, int? bitDepth, int? sampleRate,
  }) async {
    try {
      await PlatformBridge.invoke('removeFromCollection', {
        'collection_id': playlistId, 'item_id': trackKey,
      });
      await PlatformBridge.invoke('addToCollection', {
        'collection_id': playlistId, 'item_id': trackKey, 'item_json': trackJson,
      });
    } catch (e) { _plLog.w('Go updatePlaylistTrackPaths failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<List<({String playlistId, String trackKey})>> getPlaylistTracksByCanonicalKey(String canonicalKey) async {
    try {
      final result = await PlatformBridge.invoke('getCollectionItemIDsByItemID', {'item_id': canonicalKey});
      final decoded = _decodeJsonList(result);
      if (decoded != null) {
        return decoded.map((r) => (
          playlistId: (r['collection_id'] ?? r['collectionId'] ?? '') as String,
          trackKey: (r['item_id'] ?? r['itemId'] ?? '') as String,
        )).toList();
      }
      _plLog.w('Go getPlaylistTracksByCanonicalKey returned empty result');
      return [];
    } catch (e) {
      _plLog.w('Go getPlaylistTracksByCanonicalKey failed: $e');
      return [];
    }
  }

  Future<List<PlaylistPickerSummaryRow>> loadPlaylistPickerSummaries(List<String> keys) async {
    try {
      final result = await PlatformBridge.invoke('getAllCollections');
      final decoded = _decodeJsonList(result);
      if (decoded != null) {
        return decoded.where((c) => c['type'] == 'playlist').map((r) => PlaylistPickerSummaryRow(
          id: (r['id'] ?? '') as String,
          name: (r['name'] ?? '') as String,
          coverImagePath: r['cover_path'] as String?,
          createdAt: DateTime.parse((r['created_at'] ?? DateTime.now().toIso8601String()) as String),
          updatedAt: DateTime.parse((r['updated_at'] ?? DateTime.now().toIso8601String()) as String),
          trackCount: 0,
          containsAllRequestedTracks: false,
        )).toList();
      }
    } catch (e) {
      _plLog.w('Go loadPlaylistPickerSummaries failed: $e');
      return [];
    }
    return [];
  }

  List<Map<String, dynamic>>? _decodeJsonList(dynamic json) {
    if (json is! String || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    } catch (_) {}
    return null;
  }
}
