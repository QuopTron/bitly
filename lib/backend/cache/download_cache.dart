import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import '../database/app_database.dart';
import '../database/daos/download_dao.dart';

/// Download history local cache — wrappers over [DownloadDao].
class DownloadCache {
  final DownloadDao _d;
  DownloadCache(AppDatabase db) : _d = DownloadDao(db);

  Future<String> getDownloadHistory({String? since}) async {
    final items = await _d.getHistory(since: since);
    final list = items.map((e) => <String, dynamic>{
      'id': e.id, 'track_name': e.trackName,
      'artist_name': e.artistName, 'album_name': e.albumName ?? '',
      'isrc': e.isrc ?? '', 'file_path': e.filePath ?? '',
      'service': e.service ?? '', 'duration': e.duration ?? 0,
      'downloaded_at': e.downloadedAt.toIso8601String(),
      'providerTrackId': e.providerTrackId ?? e.id,
      'providerSource': e.providerSource ?? e.service ?? '',
      'cover_url': e.coverUrl ?? '', 'cover_path': e.coverPath ?? '',
    }).toList();
    return jsonEncode(list);
  }

  Future<String> getDownloadedBatches({String? since}) async {
    final items = await _d.getBatches(since: since);
    final list = items.map((e) => <String, dynamic>{
      'batch_key': e.batchKey, 'item_type': e.itemType ?? '',
      'item_id': e.itemId ?? '', 'source': e.source ?? '',
      'name': e.name ?? '', 'downloaded_at': e.downloadedAt.toIso8601String(),
      'track_ids': e.trackIds ?? '',
    }).toList();
    return jsonEncode(list);
  }

  Future<void> saveDownloadedBatch(
    String key, String type, String id, String source, String name, {
    List<String>? trackIds,
  }) => _d.saveBatch(DownloadBatchesCompanion(
    batchKey: Value(key), itemType: Value(type),
    itemId: Value(id), source: Value(source), name: Value(name),
    trackIds: trackIds != null ? Value(jsonEncode(trackIds)) : const Value.absent(),
    downloadedAt: Value(DateTime.now()),
  ));

  Future<void> saveDownloadedTrack({
    required String id,
    required String trackName,
    required String artistName,
    String? albumName,
    String? isrc,
    String? filePath,
    String? service,
    int? duration,
    String? providerTrackId,
    String? providerSource,
    String? coverUrl,
    String? coverPath,
  }) => _d.saveEntry(DownloadHistoryCompanion.insert(
    id: id,
    trackName: trackName,
    artistName: artistName,
    downloadedAt: DateTime.now(),
    albumName: albumName != null ? Value(albumName) : const Value.absent(),
    isrc: isrc != null ? Value(isrc) : const Value.absent(),
    filePath: filePath != null ? Value(filePath) : const Value.absent(),
    service: service != null ? Value(service) : const Value.absent(),
    duration: duration != null ? Value(duration) : const Value.absent(),
    providerTrackId: providerTrackId != null ? Value(providerTrackId) : const Value.absent(),
    providerSource: providerSource != null ? Value(providerSource) : const Value.absent(),
    coverUrl: coverUrl != null ? Value(coverUrl) : const Value.absent(),
    coverPath: coverPath != null ? Value(coverPath) : const Value.absent(),
  ));

  Future<void> deleteDownloadedTracks(List<String> ids) async {
    for (final id in ids) { await _d.removeById(id); }
  }

  Future<DownloadBatche?> getBatchByItem(
    String itemType, String itemId, String source,
  ) => _d.getBatchByItem(itemType, itemId, source);

  Future<void> removeDownloadedBatchByItem(
    String itemType, String itemId, String source,
  ) => _d.removeBatchByItem(itemType, itemId, source);

  Future<void> removeDownloadedBatches(List<String> keys) =>
      _d.removeBatches(keys);
}

