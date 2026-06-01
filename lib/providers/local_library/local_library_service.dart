import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/services/library/library_database.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/local_library_scan_prefs.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('LocalLibraryService');

class LocalLibraryService {
  final LibraryDatabase _db = LibraryDatabase.instance;

  Future<List<LocalLibraryItem>> getAllTracks() async {
    return await _db.getAll();
  }

  Future<List<LocalLibraryAlbumGroup>> getAlbums() async {
    return await _db.getAlbumPage(1000, 0);
  }

  Future<void> removeItem(String id) async {
    await _db.delete(id);
  }

  Future<void> updateItem(LocalLibraryItem item) async {
    await _db.update(item);
  }

  Future<LocalLibraryItem?> getById(String id) async {
    return await _db.getById(id);
  }

  Future<LocalLibraryItem?> getByIsrc(String isrc) async {
    return await _db.getByIsrc(isrc);
  }

  Future<LocalLibraryItem?> findByTrackAndArtist(String trackName, String artistName) async {
    return await _db.findFirstByTrackAndArtist(trackName, artistName);
  }

  Future<List<LocalLibraryItem>> search(String query) async {
    if (query.isEmpty) return [];
    return await _db.search(query);
  }

  Future<int> getCount() async {
    return await _db.getAlbumCount();
  }

  Future<void> clearAll() async {
    await _db.clearAll();
  }

  Future<int> cleanupMissingFiles(Set<String> existingPaths) async {
    return await _db.cleanupMissingFiles(existingPaths: existingPaths);
  }

  Future<Set<String>> scanFilePaths(
    String libraryPath, {
    String? iosBookmark,
  }) async {
    final scanResult = (iosBookmark != null && iosBookmark.isNotEmpty)
        ? await PlatformBridge.scanSafTree(iosBookmark)
        : await PlatformBridge.scanLibraryFolder(libraryPath);

    return scanResult
        .map((item) => item['filePath'] as String?)
        .whereType<String>()
        .toSet();
  }

  StreamSubscription<Map<String, dynamic>> listenToScanProgress({
    required void Function(Map<String, dynamic>) onData,
    required void Function(Object) onError,
  }) {
    return PlatformBridge.libraryScanProgressStream().listen(
      onData,
      onError: onError,
      cancelOnError: false,
    );
  }

  Future<List<Map<String, dynamic>>> performScan(
    String libraryPath, {
    String? iosBookmark,
  }) async {
    return (iosBookmark != null && iosBookmark.isNotEmpty)
        ? await PlatformBridge.scanSafTree(iosBookmark)
        : await PlatformBridge.scanLibraryFolder(libraryPath);
  }

  Future<void> cancelScan() async {
    await PlatformBridge.cancelLibraryScan();
  }

  Future<void> replaceAll(List<Map<String, dynamic>> items) async {
    await _db.replaceAll(items);
  }

  Future<void> saveLastScanTime() async {
    final prefs = await SharedPreferences.getInstance();
    await writeLocalLibraryLastScannedAt(prefs, DateTime.now());
  }

  static int? parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static double? parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}