/// Puente singleton hacia el backend Go para estadísticas de reproducción.
/// Gestiona logging de plays, consulta de estadísticas totales, tops
/// (tracks, álbumes, artistas), plays recientes y progreso de logros.
/// Las operaciones de secretos están en [StatsSecrets].
library;

import 'dart:convert';
import 'package:bitly/services/utilities/database_utils.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';

final _statsLog = AppLogger('StatsDb');

class StatsDatabase {
  static final StatsDatabase instance = StatsDatabase._init();
  StatsDatabase._init();

  Future<void> logPlay({
    required String trackId,
    required String trackName,
    required String artistName,
    String? albumName,
    String? coverUrl,
    String? source,
    String? isrc,
    int? durationSeconds,
  }) async {
    try {
      await PlatformBridge.invoke('logPlay', {
        'track_id': trackId,
        'track_name': trackName,
        'artist_name': artistName,
        'album_name': albumName ?? '',
        'played_at': DateTime.now().toUtc().toIso8601String(),
        'duration_ms': (durationSeconds ?? 0) * 1000,
        'percentage': 100,
      });
    } catch (e) {
      _statsLog.w('Go logPlay failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<Map<String, dynamic>> getTotalStats() async {
    try {
      final result = await PlatformBridge.invoke('getTotalStats');
      if (result is String && result.isNotEmpty) {
        final decoded = jsonDecode(result);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      }
      _statsLog.w('Go getTotalStats returned empty result');
      return _defaultStats();
    } catch (e) {
      _statsLog.w('Go getTotalStats failed: $e');
      return _defaultStats();
    }
  }

  Future<List<Map<String, dynamic>>> getTopTracks({int limit = 10}) async {
    return _fetchList('getTopTracks', {'limit': limit});
  }

  Future<List<Map<String, dynamic>>> getTopAlbums({int limit = 10}) async {
    return _fetchList('getTopAlbums', {'limit': limit});
  }

  Future<List<Map<String, dynamic>>> getTopArtists({int limit = 10}) async {
    return _fetchList('getTopArtists', {'limit': limit});
  }

  Future<List<Map<String, dynamic>>> getRecentPlays({int limit = 50}) async {
    return _fetchList('getRecentPlays', {'limit': limit});
  }

  Future<Map<String, int>> getAchievementProgress() async {
    final stats = await getTotalStats();
    return {
      'totalPlays': stats['totalPlays'] as int? ?? 0,
      'uniqueTracks': stats['uniqueTracks'] as int? ?? 0,
      'uniqueAlbums': stats['uniqueAlbums'] as int? ?? 0,
      'uniqueArtists': stats['uniqueArtists'] as int? ?? 0,
      'nightPlays': await _getSecretCounter('night_plays'),
      'maxAlbumStreak': await _getSecretCounter('max_album_streak'),
    };
  }

  Future<void> clearAllStats() async {
    try {
      await PlatformBridge.invoke('clearAllStats');
    } catch (e) {
      _statsLog.w('Go clearAllStats failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<int> _getSecretCounter(String key) async {
    try {
      final result = await PlatformBridge.invoke('getSecretCounter', {'key': key});
      if (result is int) return result;
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchList(String method, Map<String, dynamic> params) async {
    try {
      final result = await PlatformBridge.invoke(method, params);
      if (result is String && result.isNotEmpty) {
        final decoded = _decodeJsonList(result);
        if (decoded != null) return decoded;
      }
      _statsLog.w('Go $method returned empty result');
      return [];
    } catch (e) {
      _statsLog.w('Go $method failed: $e');
      return [];
    }
  }

  Map<String, dynamic> _defaultStats() {
    return {
      'totalPlays': 0, 'uniqueTracks': 0,
      'uniqueAlbums': 0, 'uniqueArtists': 0, 'totalDays': 0,
    };
  }

  List<Map<String, dynamic>>? _decodeJsonList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    } catch (_) {}
    return null;
  }
}
