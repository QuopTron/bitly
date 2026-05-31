/// Puente singleton hacia el backend Go para el historial de descargas.
/// Proporciona CRUD completo: insertar, actualizar, consultar, eliminar
/// entradas de descarga. Las operaciones de búsqueda avanzada están en
/// [HistoryLookup] y los modelos en [HistoryLookupRequest].
library;

export 'package:bitly/services/historial/history_models.dart';
import 'package:bitly/services/historial/history_models.dart';

import 'dart:convert';
import 'package:bitly/services/utilidades/database_utils.dart';
import 'package:bitly/services/historial/history_lookup.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('HistoryDb');

class HistoryDatabase {
  static final HistoryDatabase instance = HistoryDatabase._init();
  HistoryDatabase._init();

  static String normalizeIsrc(String? value) => DatabaseUtils.normalizeIsrc(value);
  static String matchKeyFor(String? t, String? a) => DatabaseUtils.matchKeyFor(t, a);

  Future<void> insert(Map<String, dynamic> item) async {
    try {
      await PlatformBridge.invoke('upsertDownloadEntry', {'request': _toGoEntry(item)});
    } catch (e) {
      _log.w('Go upsert failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<void> upsert(Map<String, dynamic> item) async => insert(item);

  Future<void> updateVideoPath(String id, String videoPath) async {
    try {
      await PlatformBridge.invoke('updateDownloadFilePath', {'id': id, 'file_path': videoPath});
    } catch (e) {
      _log.w('Go updateVideoPath failed: $e');
    }
  }

  Future<void> insertBatch(List<Map<String, dynamic>> items) async {
    for (final item in items) await insert(item);
  }

  Future<void> upsertBatch(List<Map<String, dynamic>> items) async => insertBatch(items);

  Future<List<Map<String, dynamic>>> getAll({int? limit, int? offset}) async {
    try {
      final result = await PlatformBridge.invoke('getDownloadHistory', {
        'limit': limit ?? 100, 'offset': offset ?? 0,
      });
      if (result is String && result.isNotEmpty) {
        final list = _decodeJsonList(result);
        if (list != null) return list;
      }
    } catch (e) {
      _log.w('Go getAll failed: $e');
    }
    return [];
  }

  Future<List<String>> getAllFilePaths() async {
    try {
      final result = await PlatformBridge.invoke('getDownloadHistoryFilePaths');
      if (result is String && result.isNotEmpty) {
        final list = _decodeJsonList(result);
        if (list != null) return list.cast<String>();
      }
    } catch (e) {
      _log.w('Go getAllFilePaths failed: $e');
    }
    return [];
  }

  Future<int> getCount() async {
    try {
      final result = await PlatformBridge.invoke('getDownloadHistoryCount');
      if (result is int) return result;
    } catch (e) {
      _log.w('Go getCount failed: $e');
    }
    return 0;
  }

  Future<Map<String, int>> getGroupedCounts() async {
    try {
      final result = await PlatformBridge.invoke('getDownloadHistoryGroupedCounts');
      if (result is String && result.isNotEmpty) {
        final decoded = _decodeJson(result);
        if (decoded is Map) {
          return {
            'albumCount': (decoded['albumCount'] as num?)?.toInt() ?? 0,
            'singleTrackCount': (decoded['singleTrackCount'] as num?)?.toInt() ?? 0,
          };
        }
      }
    } catch (e) {
      _log.w('Go getGroupedCounts failed: $e');
      return {};
    }
    _log.w('Go getGroupedCounts returned empty result');
    return {};
  }

  Future<Set<String>> existingTrackKeys(List<dynamic> requests) async {
    try {
      final result = await PlatformBridge.invoke('existingDownloadTrackKeys', {
        'request': _encodeJson(requests),
      });
      if (result is String && result.isNotEmpty) {
        final decoded = _decodeJson(result);
        if (decoded is Map) {
          return decoded.keys.where((k) => decoded[k] == true).cast<String>().toSet();
        }
      }
    } catch (e) {
      _log.w('Go existingTrackKeys failed: $e');
      return {};
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> getAlbumTracks(String album, String artist) async {
    return _fetchList('getDownloadAlbumTracks', {'album': album, 'artist': artist});
  }

  Future<List<Map<String, dynamic>>> getArtistTracks(String artist) async {
    return _fetchList('getDownloadArtistTracks', {'artist': artist});
  }

  Future<int> deleteByIds(List<String> ids) async {
    try {
      await PlatformBridge.invoke('deleteDownloadEntriesByIDs', _encodeJson(ids));
      return ids.length;
    } catch (e) {
      _log.w('Go deleteByIds failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<int> deleteById(String id) async => deleteByIds([id]);

  Future<int> deleteByTrackMatch(String t, String a) async {
    try {
      await PlatformBridge.invoke('deleteDownloadEntriesByTrackMatch', {
        'track_name': t, 'artist_name': a,
      });
      return 1;
    } catch (e) {
      _log.w('Go deleteByTrackMatch failed: $e');
    }
    final item = await _findFirstFallback(t, a);
    if (item != null) return deleteById(item['id']);
    return 0;
  }

  Future<int> deleteBySpotifyId(String sid) async {
    final item = await _getBySpotifyIdFallback(sid);
    if (item != null) return deleteById(item['id']);
    return 0;
  }

  Future<int> updateFilePath(String id, String path, {String? newSafFileName, String? newQuality, bool clearAudioSpecs = false}) async {
    try {
      await PlatformBridge.invoke('updateDownloadFilePath', {'id': id, 'file_path': path});
      return 1;
    } catch (e) {
      _log.w('Go updateFilePath failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<int> clearAll() async {
    try {
      final result = await PlatformBridge.invoke('clearDownloadHistory');
      return result is int ? result : 0;
    } catch (e) {
      _log.w('Go clearAll failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<List<Map<String, dynamic>>> getEntriesWithPathsPage(int limit, int offset) async {
    return getAll(limit: limit, offset: offset);
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
      await PlatformBridge.invoke('updateDownloadAudioMetadata', {'request': _encodeJson(entry)});
      return 1;
    } catch (e) {
      _log.w('Go updateAudioMetadata failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<Map<String, dynamic>?> _findFirstFallback(String t, String a) async {
    try {
      final result = await PlatformBridge.invoke('findDownloadEntryByTrackAndArtist', {
        'track_name': t, 'artist_name': a,
      });
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = _decodeJson(result);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _getBySpotifyIdFallback(String sid) async {
    try {
      final result = await PlatformBridge.invoke('getDownloadEntryBySpotifyID', {'request': sid});
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = _decodeJson(result);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchList(String method, Map<String, dynamic> params) async {
    try {
      final result = await PlatformBridge.invoke(method, params);
      if (result is String && result.isNotEmpty) {
        final list = _decodeJsonList(result);
        if (list != null) return list;
      }
    } catch (e) {
      _log.w('Go $method failed: $e');
    }
    return [];
  }

  String _encodeJson(dynamic obj) {
    try { return jsonEncode(obj); } catch (_) { return '[]'; }
  }

  List<Map<String, dynamic>>? _decodeJsonList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    } catch (_) {}
    return null;
  }

  dynamic _decodeJson(String json) {
    try { return jsonDecode(json); } catch (_) { return null; }
  }

  String _toGoEntry(Map<String, dynamic> item) {
    final map = <String, dynamic>{
      'id': item['id'], 'trackName': item['trackName'], 'artistName': item['artistName'],
      'albumName': item['albumName'], 'albumArtist': item['albumArtist'], 'filePath': item['filePath'],
      'coverUrl': item['coverUrl'], 'coverPath': item['coverPath'], 'isrc': item['isrc'],
      'duration': item['duration'], 'trackNumber': item['trackNumber'], 'totalTracks': item['totalTracks'],
      'discNumber': item['discNumber'], 'totalDiscs': item['totalDiscs'], 'releaseDate': item['releaseDate'],
      'genre': item['genre'], 'composer': item['composer'], 'label': item['label'],
      'copyright': item['copyright'], 'quality': item['quality'], 'bitDepth': item['bitDepth'],
      'sampleRate': item['sampleRate'], 'bitrate': item['bitrate'], 'spotifyId': item['spotifyId'],
      'downloadedAt': item['downloadedAt'] ?? DateTime.now().toIso8601String(),
      'service': item['service'], 'storageMode': item['storageMode'],
      'safFileName': item['newSafFileName'] ?? item['safFileName'],
      'safRelativeDir': item['safRelativeDir'], 'videoFilePath': item['videoFilePath'],
      'format': item['format'],
    };
    return _encodeJson(map);
  }

  // Public lookup methods used by providers
  Future<Map<String, dynamic>?> getBySpotifyId(String sid) async => _getBySpotifyIdFallback(sid);

  Future<Map<String, dynamic>?> getByIsrc(String isrc) async {
    try {
      final result = await PlatformBridge.invoke('getDownloadEntryByISRC', {'request': isrc});
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = _decodeJson(result);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> findByTrackAndArtist(String t, String a) async => _findFirstFallback(t, a);

  Future<Map<String, dynamic>?> findExisting({String? spotifyId, String? isrc}) async {
    if (spotifyId != null && spotifyId.isNotEmpty) {
      final byId = await getBySpotifyId(spotifyId);
      if (byId != null) return byId;
    }
    if (isrc != null && isrc.isNotEmpty) {
      final byIsrc = await getByIsrc(isrc);
      if (byIsrc != null) return byIsrc;
    }
    return null;
  }

  Future<Map<String, dynamic>?> findExistingTrack(HistoryLookupRequest request) async {
    if (request.spotifyId.isNotEmpty) {
      final byId = await getBySpotifyId(request.spotifyId);
      if (byId != null) return byId;
    }
    final isrc = request.isrc?.trim();
    if (isrc != null && isrc.isNotEmpty) {
      final byIsrc = await getByIsrc(isrc);
      if (byIsrc != null) return byIsrc;
    }
    return findByTrackAndArtist(request.trackName, request.artistName);
  }

  Future<bool> existsTrack(HistoryLookupRequest request) async {
    final existing = await findExistingTrack(request);
    return existing != null;
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    try {
      final result = await PlatformBridge.invoke('getDownloadEntryByID', {'id': id});
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = _decodeJson(result);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    return null;
  }
}
