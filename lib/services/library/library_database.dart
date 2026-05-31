/// Puente singleton hacia el backend Go para la biblioteca local.
/// Proporciona CRUD básico (upsert, delete, clearAll) y métodos de utilidad.
/// Las operaciones de consulta avanzada están en [LibraryQueryService],
/// las de archivos en [LibraryFileOps].
library;

export 'package:bitly/services/library/library_models.dart';
export 'package:bitly/services/library/library_query_service.dart';
export 'package:bitly/services/library/library_file_ops.dart';
import 'package:bitly/services/library/library_query_service.dart';

import 'dart:convert';
import 'package:bitly/services/utilities/database_utils.dart';
import 'package:bitly/services/library/library_models.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';

final _libLog = AppLogger('LibraryDb');

class LibraryDatabase {
  static final LibraryDatabase instance = LibraryDatabase._init();
  LibraryDatabase._init();

  static String normalizeLookupText(String? text) => (text ?? '').toLowerCase().trim();
  static String matchKeyFor(String? track, String? artist) => DatabaseUtils.matchKeyFor(track, artist);

  Future<void> upsert(dynamic item) async {
    Map<String, dynamic>? data;
    if (item is LocalLibraryItem) data = item.toJson();
    else if (item is Map<String, dynamic>) data = item;
    if (data == null) return;
    try {
      final entry = {
        'id': data['id'], 'trackName': data['trackName'], 'artistName': data['artistName'],
        'albumName': data['albumName'], 'albumArtist': data['albumArtist'], 'filePath': data['filePath'],
        'coverPath': data['coverPath'], 'isrc': data['isrc'], 'duration': data['duration'],
        'trackNumber': data['trackNumber'], 'totalTracks': data['totalTracks'], 'discNumber': data['discNumber'],
        'totalDiscs': data['totalDiscs'], 'releaseDate': data['releaseDate'], 'genre': data['genre'],
        'composer': data['composer'], 'label': data['label'], 'copyright': data['copyright'],
        'format': data['format'], 'bitDepth': data['bitDepth'], 'sampleRate': data['sampleRate'],
        'bitrate': data['bitrate'],
      };
      await PlatformBridge.invoke('upsertLocalLibraryEntry', {'request': jsonEncode(entry)});
    } catch (e) {
      _libLog.w('Go upsert failed, fallback: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<void> update(LocalLibraryItem item) async => upsert(item);

  Future<void> upsertBatch(List<dynamic> items) async {
    for (final item in items) await upsert(item);
  }

  Future<int> deleteByPath(String path) async {
    try { await PlatformBridge.invoke('deleteLocalLibraryEntriesByPaths', {'request': jsonEncode([path])}); return 1; }
    catch (e) { _libLog.w('Go deleteByPath failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<int> delete(String id) async {
    try { await PlatformBridge.invoke('deleteLocalLibraryEntryByID', {'id': id}); return 1; }
    catch (e) { _libLog.w('Go delete failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<int> deleteByPaths(List<String> paths) async {
    try { await PlatformBridge.invoke('deleteLocalLibraryEntriesByPaths', {'request': jsonEncode(paths)}); return paths.length; }
    catch (e) { 
      _libLog.w('Go deleteByPaths failed, fallback: $e');
      int c = 0; 
      for (final p in paths) c += await deleteByPath(p); 
      return c; 
    }
  }

  Future<int> clearAll() async {
    try { await PlatformBridge.invoke('clearLocalLibrary'); return 0; }
    catch (e) { _libLog.w('Go clearAll failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<void> replaceAll(List<dynamic> items) async {
    await clearAll();
    await upsertBatch(items);
  }

  // Public query methods used by providers
  Future<List<LocalLibraryItem>> getAll({int? limit, int? offset}) async {
    try {
      return await LibraryQueryService.instance.getAll(
        LocalLibraryPageRequest(limit: limit ?? 1000, offset: offset ?? 0),
      );
    } catch (e) {
      _libLog.w('getAll failed: $e');
    }
    return [];
  }

  Future<List<LocalLibraryAlbumGroup>> getAlbumPage(int limit, int offset) async {
    try {
      return await LibraryQueryService.instance.getAlbumPage(
        limit: limit, offset: offset,
      );
    } catch (e) {
      _libLog.w('getAlbumPage failed: $e');
    }
    return [];
  }

  Future<LocalLibraryItem?> getById(String id) async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryEntryByID', {'id': id});
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = jsonDecode(result);
        if (decoded is Map) return LocalLibraryItem.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      _libLog.w('Go getById failed: $e');
    }
    return null;
  }

  Future<LocalLibraryItem?> getByIsrc(String isrc) async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryEntryByIsrc', {'isrc': isrc});
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = jsonDecode(result);
        if (decoded is Map) return LocalLibraryItem.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      _libLog.w('Go getByIsrc failed: $e');
    }
    return null;
  }

  Future<LocalLibraryItem?> findFirstByTrackAndArtist(String track, String artist) async {
    try {
      final result = await PlatformBridge.invoke('findLocalLibraryEntryByTrackAndArtist', {
        'track_name': track,
        'artist_name': artist,
      });
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = jsonDecode(result);
        if (decoded is Map) return LocalLibraryItem.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      _libLog.w('Go findFirstByTrackAndArtist failed: $e');
    }
    return null;
  }

  Future<List<LocalLibraryItem>> search(String query) async {
    try {
      return await LibraryQueryService.instance.search(query);
    } catch (e) {
      _libLog.w('search failed: $e');
    }
    return [];
  }

  Future<int> getAlbumCount() async {
    try {
      return await LibraryQueryService.instance.getAlbumCount();
    } catch (e) {
      _libLog.w('getAlbumCount failed: $e');
    }
    return 0;
  }

  Future<int> cleanupMissingFiles({Set<String>? existingPaths}) async {
    if (existingPaths == null || existingPaths.isEmpty) return 0;
    try {
      final result = await PlatformBridge.invoke('cleanupLocalLibraryMissingFiles', {
        'request': jsonEncode(existingPaths.toList()),
      });
      if (result is int) return result;
      if (result is String) return int.tryParse(result) ?? 0;
    } catch (e) {
      _libLog.w('Go cleanupMissingFiles failed, fallback: $e');
    }
    // Fallback: iterate and delete one by one
    try {
      final all = await getAll();
      int removed = 0;
      for (final item in all) {
        if (!existingPaths.contains(item.filePath)) {
          await delete(item.id);
          removed++;
        }
      }
      return removed;
    } catch (e) {
      _libLog.w('cleanupMissingFiles fallback failed: $e');
      return 0;
    }
  }

  // Queue helpers used by queue_tab / queue_tab_helpers
  // Delegated to LibraryQueryService which uses real Go backend methods.
  Future<List<Map<String, dynamic>>> getQueueAlbumPage({required QueueLibraryDbQuery query}) async {
    try {
      return await LibraryQueryService.instance.getQueueAlbumPage(query: query);
    } catch (e) {
      _libLog.w('getQueueAlbumPage failed: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getQueueTrackPage({required QueueLibraryDbQuery query}) async {
    try {
      return await LibraryQueryService.instance.getQueueTrackPage(query: query);
    } catch (e) {
      _libLog.w('getQueueTrackPage failed: $e');
    }
    return [];
  }

  Future<QueueLibraryCounts> getQueueCounts({required QueueLibraryDbQuery query}) async {
    try {
      return await LibraryQueryService.instance.getQueueCounts(query: query);
    } catch (e) {
      _libLog.w('getQueueCounts failed: $e');
    }
    return const QueueLibraryCounts(allTrackCount: 0, albumCount: 0, singleTrackCount: 0);
  }

  Future<void> updateAudioMetadata(
    String id, {
    int? duration,
    int? bitDepth,
    int? sampleRate,
    int? trackNumber,
    int? totalTracks,
    int? discNumber,
    int? totalDiscs,
    String? composer,
    String? label,
    String? copyright,
  }) async {
    try {
      final existing = await getById(id);
      if (existing == null) {
        _libLog.w('updateAudioMetadata: item $id not found');
        return;
      }
      await upsert(existing.copyWith(
        duration: duration ?? existing.duration,
        bitDepth: bitDepth ?? existing.bitDepth,
        sampleRate: sampleRate ?? existing.sampleRate,
        trackNumber: trackNumber ?? existing.trackNumber,
        totalTracks: totalTracks ?? existing.totalTracks,
        discNumber: discNumber ?? existing.discNumber,
        totalDiscs: totalDiscs ?? existing.totalDiscs,
        composer: composer ?? existing.composer,
        label: label ?? existing.label,
        copyright: copyright ?? existing.copyright,
      ));
    } catch (e) {
      _libLog.w('updateAudioMetadata failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<void> replaceWithConvertedItem({
    required LocalLibraryItem item,
    required String newFilePath,
    required String targetFormat,
    int? bitrate,
  }) async {
    try {
      final entry = {
        'id': item.id,
        'newFilePath': newFilePath,
        'targetFormat': targetFormat,
        'bitrate': bitrate,
      };
      await PlatformBridge.invoke('replaceLocalLibraryConvertedItem', {'request': jsonEncode(entry)});
    } catch (e) {
      _libLog.w('Go replaceWithConvertedItem failed, fallback: $e');
      await upsert(item.copyWith(filePath: newFilePath, format: targetFormat, bitrate: bitrate));
    }
  }
}
