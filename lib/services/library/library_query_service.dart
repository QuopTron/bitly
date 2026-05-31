/// Servicio de consultas y paginación de la biblioteca local.
/// Proporciona métodos para obtener páginas de tracks, álbumes,
/// counts, tracks por artista/álbum e índices de búsqueda.
library;

import 'dart:convert';
import 'package:bitly/services/library/library_models.dart';
import 'package:bitly/services/utilities/database_utils.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';

final _qLog = AppLogger('LibQuery');

class LibraryQueryService {
  static final LibraryQueryService instance = LibraryQueryService._init();
  LibraryQueryService._init();

  Future<List<LocalLibraryItem>> getAll([LocalLibraryPageRequest? req]) async {
    final rows = await _getLibraryRaw(limit: req?.limit, offset: req?.offset, searchQuery: req?.searchQuery, sortMode: req?.sortMode.name);
    return rows.map(LocalLibraryItem.fromJson).toList();
  }

  Future<int> getCount({LocalLibraryPageRequest? request}) async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryCount', {'searchQuery': request?.searchQuery ?? ''});
      if (result is int) return result;
    } catch (e) { _qLog.w('Go getCount failed: $e'); }
    return 0;
  }

  Future<int> getPageCount(LocalLibraryPageRequest req) async => getCount(request: req);

  Future<List<LocalLibraryItem>> search(String query) => getAll(LocalLibraryPageRequest(searchQuery: query));
  Future<List<LocalLibraryItem>> getPage(LocalLibraryPageRequest req) => getAll(req);

  Future<List<LocalLibraryAlbumGroup>> getAlbumPage({LocalLibraryPageRequest? request, int? limit, int? offset, String? filterMode, String? sortMode, String? searchQuery}) async {
    try {
      final l = limit ?? request?.limit ?? 100;
      final o = offset ?? request?.offset ?? 0;
      final sq = searchQuery ?? request?.searchQuery ?? '';
      final result = await PlatformBridge.invoke('getLocalLibraryAlbumGroups', {'limit': l, 'offset': o, 'searchQuery': sq});
      if (result is String && result.isNotEmpty) {
        final decoded = _decodeJsonList(result);
        if (decoded != null) {
          return decoded.map((r) => LocalLibraryAlbumGroup(
            albumName: r['album_name'] as String, artistName: r['artist_name'] as String,
            coverPath: r['cover_path'] as String?, trackCount: r['track_count'] as int,
            latestScannedAt: DateTime.tryParse(r['latest_scanned']?.toString() ?? '') ?? DateTime.now(),
          )).toList();
        }
      }
    } catch (e) { _qLog.w('Go getAlbumPage failed: $e'); throw DatabaseUtils.dbError(); }
    return [];
  }

  Future<int> getAlbumCount([LocalLibraryPageRequest? req]) async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryAlbumGroupCount', {'searchQuery': req?.searchQuery ?? ''});
      if (result is int) return result;
    } catch (e) { _qLog.w('Go getAlbumCount failed: $e'); throw DatabaseUtils.dbError(); }
    return 0;
  }

  Future<QueueLibraryCounts> getQueueCounts({QueueLibraryDbQuery? query}) async {
    final allTrackCount = await getCount(request: query != null ? LocalLibraryPageRequest(searchQuery: query.searchQuery) : null);
    final albumCount = await getAlbumCount();
    final singleTrackCount = await _getSingleTrackCount(query);
    return QueueLibraryCounts(allTrackCount: allTrackCount, albumCount: albumCount, singleTrackCount: singleTrackCount);
  }

  Future<int> _getSingleTrackCount(QueueLibraryDbQuery? query) async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibrarySingleTrackCount', {'searchQuery': query?.searchQuery ?? ''});
      if (result is int) return result;
      if (result is String) return int.tryParse(result) ?? 0;
    } catch (e) { _qLog.w('Go _getSingleTrackCount failed: $e'); }
    return 0;
  }

  Future<List<Map<String, dynamic>>> getQueueAlbumPage({QueueLibraryDbQuery? query, int? limit, int? offset}) async {
    final rows = await getAlbumPage(limit: limit ?? query?.limit ?? 100, offset: offset ?? query?.offset ?? 0, searchQuery: query?.searchQuery);
    return rows.map((r) => {'queue_source': 'local', 'album_name': r.albumName, 'artist_name': r.artistName, 'cover_path': r.coverPath, 'track_count': r.trackCount, 'sort_added': r.latestScannedAt.millisecondsSinceEpoch}).toList();
  }

  Future<List<Map<String, dynamic>>> getQueueTrackPage({QueueLibraryDbQuery? query, int? limit, int? offset}) async {
    final rows = await _getLibraryRaw(limit: limit ?? query?.limit, offset: offset ?? query?.offset, sortMode: 'title', searchQuery: query?.searchQuery);
    return rows.map((r) => {'source': 'local', 'item': r}).toList();
  }

  Future<LibraryLookupIndex> getLookupIndex() async {
    try {
      final rows = await _getAllLibraryRowsInternal();
      return _buildLookupIndex(rows);
    } catch (e) { _qLog.w('Go getLookupIndex failed: $e'); throw DatabaseUtils.dbError(); }
  }

  Future<List<LocalLibraryItem>> getArtistTracks(String artist) async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryArtistTracks', {'artist': artist});
      if (result is String && result.isNotEmpty) {
        final decoded = _decodeJsonList(result);
        if (decoded != null) return decoded.map(LocalLibraryItem.fromJson).toList();
      }
    } catch (e) { _qLog.w('Go getArtistTracks failed: $e'); throw DatabaseUtils.dbError(); }
    return [];
  }

  Future<List<LocalLibraryItem>> getAlbumTracks(String album, String artist) async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryAlbumTracks', {'album': album, 'artist': artist});
      if (result is String && result.isNotEmpty) {
        final decoded = _decodeJsonList(result);
        if (decoded != null) return decoded.map(LocalLibraryItem.fromJson).toList();
      }
    } catch (e) { _qLog.w('Go getAlbumTracks failed: $e'); throw DatabaseUtils.dbError(); }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getLibraryRaw({int? limit, int? offset, String? searchQuery, String? sortMode}) async {
    try {
      final result = await PlatformBridge.invoke('getLocalLibraryPage', {'limit': limit ?? 100, 'offset': offset ?? 0, 'searchQuery': searchQuery ?? '', 'sortMode': sortMode ?? ''});
      if (result is String && result.isNotEmpty) {
        final decoded = _decodeJsonList(result);
        if (decoded != null) return decoded;
      }
    } catch (e) { _qLog.w('Go getLibraryRaw failed: $e'); }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getAllLibraryRowsInternal() async {
    final result = await PlatformBridge.invoke('getLocalLibraryPage', {'limit': 100000, 'offset': 0, 'searchQuery': '', 'sortMode': ''});
    if (result is String && result.isNotEmpty) {
      return _decodeJsonList(result) ?? [];
    }
    throw Exception('empty result');
  }

  LibraryLookupIndex _buildLookupIndex(List<Map<String, dynamic>> rows) {
    final matchKeys = <String>{}; final isrcs = <String>{}; final filePathById = <String, String>{};
    for (final r in rows) {
      final name = r['track_name']?.toString(); final artist = r['artist_name']?.toString();
      if (name != null && artist != null) matchKeys.add('${name.toLowerCase().trim()}|${artist.toLowerCase().trim()}');
      final isrc = r['isrc']?.toString(); if (isrc != null) isrcs.add(isrc);
      final id = r['id']?.toString(); final path = r['file_path']?.toString();
      if (id != null && path != null) filePathById[id] = path;
    }
    return LibraryLookupIndex(matchKeys: matchKeys, isrcs: isrcs, filePathById: filePathById);
  }

  List<Map<String, dynamic>>? _decodeJsonList(String json) {
    try { final d = jsonDecode(json); if (d is List) return d.cast<Map<String, dynamic>>(); } catch (_) {}
    return null;
  }
}
