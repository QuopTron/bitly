/// Operaciones de archivos y metadatos de la biblioteca local.
/// Incluye limpieza de archivos faltantes, gestión de rutas de carátulas,
/// modificación de tiempos de archivo, reemplazo de items convertidos
/// y actualización de metadatos de audio.
library;

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:bitly/services/history/history_models.dart';
import 'package:bitly/services/library/library_models.dart';
import 'package:bitly/services/utilities/database_utils.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';

final _fileLog = AppLogger('LibFileOps');

class LibraryFileOps {
  static final LibraryFileOps instance = LibraryFileOps._init();
  LibraryFileOps._init();

  Future<Map<String, int>> getFileModTimes() async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryPage', {
        'limit': 100000, 'offset': 0, 'searchQuery': '', 'sortMode': '',
      });
      if (result is String && result.isNotEmpty) {
        final decoded = _decodeJsonList(result);
        if (decoded != null) {
          return {for (final r in decoded) if (r['file_path'] != null) r['file_path'] as String: (r['fileModTime'] as num?)?.toInt() ?? 0};
        }
      }
    } catch (e) { _fileLog.w('Go getFileModTimes failed: $e'); throw DatabaseUtils.dbError(); }
    return {};
  }

  Future<int> updateFileModTimes(Map<String, int> modTimes) async {
    try { await PlatformBridge.invoke('updateLocalLibraryFileModTimes', {'entries': jsonEncode(modTimes)}); return modTimes.length; }
    catch (e) { _fileLog.w('Go updateFileModTimes failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<String?> writeFileModTimesSnapshot([String? path]) async => path ?? 'master_db_snapshot';

  Future<int> cleanupMissingFiles(Set<String>? existingPaths) async {
    if (existingPaths == null) return 0;
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryEntriesWithPathsPage', {'limit': 100000, 'offset': 0});
      if (result is String && result.isNotEmpty) {
        final decoded = _decodeJsonList(result);
        if (decoded != null) {
          final missing = decoded.cast<String>().toSet().difference(existingPaths);
          if (missing.isNotEmpty) return await _deleteByPaths(missing.toList());
        }
      }
    } catch (e) { _fileLog.w('Go cleanupMissingFiles failed: $e'); throw DatabaseUtils.dbError(); }
    return 0;
  }

  Future<List<String>> getCoverPaths() async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryCoverPaths');
      if (result is String && result.isNotEmpty) {
        final decoded = _decodeJsonList(result);
        if (decoded != null) return decoded.cast<String>();
      }
    } catch (e) { _fileLog.w('Go getCoverPaths failed: $e'); throw DatabaseUtils.dbError(); }
    return [];
  }

  Future<List<String>> getEntriesWithPathsPage(int limit, int offset) async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryEntriesWithPathsPage', {'limit': limit, 'offset': offset});
      if (result is String && result.isNotEmpty) {
        final decoded = _decodeJsonList(result);
        if (decoded != null) return decoded.cast<String>();
      }
    } catch (e) { _fileLog.w('Go getEntriesWithPathsPage failed: $e'); throw DatabaseUtils.dbError(); }
    return [];
  }

  Future<Map<String, dynamic>?> getByIdRaw(String id) async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryEntryByID', {'id': id});
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = _decodeJson(result);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      }
    } catch (e) { _fileLog.w('Go getByIdRaw failed: $e'); return null; }
    return null;
  }

  Future<LocalLibraryItem?> getById(String id) async {
    final row = await getByIdRaw(id);
    return row != null ? LocalLibraryItem.fromJson(row) : null;
  }

  Future<LocalLibraryItem?> getByIsrc(String isrc) async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryEntryByIsrc', {'isrc': isrc});
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = _decodeJson(result);
        if (decoded is Map) return LocalLibraryItem.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (e) {
      if (e is PlatformException && e.message?.contains('no rows in result set') == true) return null;
      _fileLog.w('Go getByIsrc failed: $e'); return null;
    }
    return null;
  }

  Future<LocalLibraryItem?> findFirstByTrackAndArtist(String track, String artist) async {
    try {
      final result = await PlatformBridge.invoke('findLocalLibraryEntryByTrackAndArtist', {'track_name': track, 'artist_name': artist});
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = _decodeJson(result);
        if (decoded is Map) return LocalLibraryItem.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (e) {
      if (e is PlatformException && e.message?.contains('no rows in result set') == true) return null;
      _fileLog.w('Go findFirstByTrackAndArtist failed: $e'); return null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> findExisting(Map<String, dynamic> request) async {
    final isrc = request['isrc'] as String?;
    if (isrc != null) {
      final res = await getByIsrc(isrc);
      if (res != null) return res.toJson();
    }
    final trackName = request['trackName'] as String?;
    final artistName = request['artistName'] as String?;
    if (trackName != null && artistName != null) {
      final res = await findFirstByTrackAndArtist(trackName, artistName);
      if (res != null) return res.toJson();
    }
    return null;
  }

  Future<void> replaceWithConvertedItem({required dynamic item, required String newFilePath, required String targetFormat, dynamic bitrate, String? newQuality, String? newSafFileName, bool clearAudioSpecs = false}) async {
    LocalLibraryItem? localItem;
    if (item is LocalLibraryItem) localItem = item;
    else if (item is Map<String, dynamic>) localItem = LocalLibraryItem.fromJson(item);
    if (localItem != null) {
      int? bitrateInt;
      if (bitrate is int) bitrateInt = bitrate;
      else if (bitrate is String) bitrateInt = int.tryParse(bitrate);
      final newItem = localItem.copyWith(filePath: newFilePath, format: targetFormat, bitrate: bitrateInt);
      await _deleteByPath(localItem.filePath);
      await _upsertItem(newItem);
    }
  }

  Future<int> updateAudioMetadata(String idOrPath, {String? trackName, String? artistName, String? albumName, String? albumArtist, String? genre, String? releaseDate, dynamic trackNumber, dynamic discNumber, String? isrc, String? label, dynamic duration, dynamic bitDepth, dynamic sampleRate}) async {
    try {
      final entry = <String, dynamic>{
        'id': idOrPath,
        if (trackName != null) 'trackName': trackName,
        if (artistName != null) 'artistName': artistName,
        if (albumName != null) 'albumName': albumName,
        if (albumArtist != null) 'albumArtist': albumArtist,
        if (genre != null) 'genre': genre,
        if (releaseDate != null) 'releaseDate': releaseDate,
        if (trackNumber != null) 'trackNumber': trackNumber is int ? trackNumber : int.tryParse(trackNumber.toString()),
        if (discNumber != null) 'discNumber': discNumber is int ? discNumber : int.tryParse(discNumber.toString()),
        if (isrc != null) 'isrc': isrc,
        if (label != null) 'label': label,
        if (duration != null) 'duration': duration is int ? duration : int.tryParse(duration.toString()),
      };
      await PlatformBridge.invoke('updateLocalLibraryAudioMetadata', {'request': jsonEncode(entry)});
      return 1;
    } catch (e) { _fileLog.w('Go updateAudioMetadata failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<int> _deleteByPath(String path) async {
    try { await PlatformBridge.invoke('deleteLocalLibraryEntriesByPaths', {'request': jsonEncode([path])}); return 1; }
    catch (e) { _fileLog.w('Go deleteByPath failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<int> _deleteByPaths(List<String> paths) async {
    try { await PlatformBridge.invoke('deleteLocalLibraryEntriesByPaths', {'request': jsonEncode(paths)}); return paths.length; }
    catch (e) { 
      _fileLog.w('Go deleteByPaths failed: $e'); 
      int c = 0; 
      for (final p in paths) c += await _deleteByPath(p); 
      return c; 
    }
  }

  Future<void> _upsertItem(LocalLibraryItem item) async {
    try { await PlatformBridge.invoke('upsertLocalLibraryEntry', {'request': jsonEncode(item.toJson())}); }
    catch (e) { _fileLog.w('Go _upsertItem failed: $e'); throw DatabaseUtils.dbError(); }
  }

  List<Map<String, dynamic>>? _decodeJsonList(String json) {
    try { final d = jsonDecode(json); if (d is List) return d.cast<Map<String, dynamic>>(); } catch (_) {}
    return null;
  }

  dynamic _decodeJson(String json) { try { return jsonDecode(json); } catch (_) { return null; } }
}
