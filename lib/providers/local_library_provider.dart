import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bitly/services/biblioteca/library_database.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/utils/local_library_scan_prefs.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('LocalLibraryProvider');

class LocalLibraryState {
  final List<LocalLibraryItem> allTracks;
  final List<LocalLibraryAlbumGroup> albums;
  final bool isLoading;
  final int loadedIndexVersion;
  final bool isScanning;
  final bool scanIsFinalizing;
  final double scanProgress;
  final String? scanCurrentFile;
  final int scanTotalFiles;
  final int scannedFiles;
  final DateTime? lastScannedAt;
  final bool scanWasCancelled;
  final int excludedDownloadedCount;
  final int totalCount;

  const LocalLibraryState({
    this.allTracks = const [],
    this.albums = const [],
    this.isLoading = false,
    this.loadedIndexVersion = 0,
    this.isScanning = false,
    this.scanIsFinalizing = false,
    this.scanProgress = 0.0,
    this.scanCurrentFile,
    this.scanTotalFiles = 0,
    this.scannedFiles = 0,
    this.lastScannedAt,
    this.scanWasCancelled = false,
    this.excludedDownloadedCount = 0,
    this.totalCount = 0,
  });

  List<LocalLibraryItem> get items => allTracks;

  LocalLibraryState copyWith({
    List<LocalLibraryItem>? allTracks,
    List<LocalLibraryAlbumGroup>? albums,
    bool? isLoading,
    int? loadedIndexVersion,
    bool? isScanning,
    bool? scanIsFinalizing,
    double? scanProgress,
    String? scanCurrentFile,
    int? scanTotalFiles,
    int? scannedFiles,
    DateTime? lastScannedAt,
    bool? scanWasCancelled,
    int? excludedDownloadedCount,
    int? totalCount,
  }) {
    return LocalLibraryState(
      allTracks: allTracks ?? this.allTracks,
      albums: albums ?? this.albums,
      isLoading: isLoading ?? this.isLoading,
      loadedIndexVersion: loadedIndexVersion ?? this.loadedIndexVersion,
      isScanning: isScanning ?? this.isScanning,
      scanIsFinalizing: scanIsFinalizing ?? this.scanIsFinalizing,
      scanProgress: scanProgress ?? this.scanProgress,
      scanCurrentFile: scanCurrentFile ?? this.scanCurrentFile,
      scanTotalFiles: scanTotalFiles ?? this.scanTotalFiles,
      scannedFiles: scannedFiles ?? this.scannedFiles,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      scanWasCancelled: scanWasCancelled ?? this.scanWasCancelled,
      excludedDownloadedCount: excludedDownloadedCount ?? this.excludedDownloadedCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  bool existsInLibrary({String? isrc, String? trackName, String? artistName}) {
    if (isrc != null && isrc.isNotEmpty) {
      if (allTracks.any((t) => t.isrc == isrc)) return true;
    }
    if (trackName != null && artistName != null) {
      final mk = LibraryDatabase.matchKeyFor(trackName, artistName).toLowerCase();
      if (allTracks.any((t) => t.matchKey.toLowerCase() == mk)) return true;
    }
    return false;
  }
}

class LocalLibraryNotifier extends StateNotifier<LocalLibraryState> {
  final LibraryDatabase _db = LibraryDatabase.instance;
  StreamSubscription<Map<String, dynamic>>? _scanProgressSubscription;

  LocalLibraryNotifier() : super(const LocalLibraryState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final tracks = await _db.getAll();
      final albums = await _db.getAlbumPage(1000, 0);
      state = state.copyWith(
        allTracks: tracks,
        albums: albums,
        isLoading: false,
        loadedIndexVersion: state.loadedIndexVersion + 1,
        totalCount: tracks.length,
      );
    } catch (e) {
      _log.e('Failed to refresh library: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> removeItem(String id) async {
    await _db.delete(id);
    await refresh();
  }

  /// Lightweight bump — just increments the version so watchers refetch
  void bumpVersion() {
    state = state.copyWith(loadedIndexVersion: state.loadedIndexVersion + 1);
  }

  Future<void> updateItem(LocalLibraryItem item) async {
    await _db.update(item);
    await refresh();
  }

  Future<LocalLibraryItem?> getById(String id) async {
    return await _db.getById(id);
  }

  Future<LocalLibraryItem?> getByIsrcAsync(String isrc) async {
    return await _db.getByIsrc(isrc);
  }

  Future<LocalLibraryItem?> findByTrackAndArtistAsync(String trackName, String artistName) async {
    return await _db.findFirstByTrackAndArtist(trackName, artistName);
  }

  Future<LocalLibraryItem?> findExistingAsync({String? isrc, String? trackName, String? artistName}) async {
    if (isrc != null && isrc.isNotEmpty) {
      final existing = await getByIsrcAsync(isrc);
      if (existing != null) return existing;
    }
    if (trackName != null && artistName != null) {
      return await findByTrackAndArtistAsync(trackName, artistName);
    }
    return null;
  }

  Future<List<LocalLibraryItem>> search(String query) async {
    if (query.isEmpty) return [];
    return await _db.search(query);
  }

  Future<int> getCount({LocalLibraryFilterMode filter = LocalLibraryFilterMode.all, LocalLibrarySortMode sort = LocalLibrarySortMode.album}) async {
    return await _db.getAlbumCount();
  }

  Future<void> reloadFromStorage() async {
    await refresh();
  }

  Future<void> startScan(
    String libraryPath, {
    String? iosBookmark,
    bool forceFullScan = false,
  }) async {
    if (state.isScanning) return;

    state = state.copyWith(
      isScanning: true,
      scanIsFinalizing: false,
      scanProgress: 0.0,
      scanCurrentFile: null,
      scanTotalFiles: 0,
      scannedFiles: 0,
      scanWasCancelled: false,
      excludedDownloadedCount: 0,
    );

    _scanProgressSubscription?.cancel();
    _scanProgressSubscription = PlatformBridge.libraryScanProgressStream().listen(
      (payload) {
        state = state.copyWith(
          scanProgress: _parseDouble(payload['scanProgress']) ?? state.scanProgress,
          scanCurrentFile: payload['scanCurrentFile'] as String?,
          scanTotalFiles: _parseInt(payload['scanTotalFiles']) ?? state.scanTotalFiles,
          scannedFiles: _parseInt(payload['scannedFiles']) ?? state.scannedFiles,
          excludedDownloadedCount: _parseInt(payload['excludedDownloadedCount']) ?? state.excludedDownloadedCount,
          scanIsFinalizing: payload['scanIsFinalizing'] == true,
        );
      },
      onError: (error) {
        _log.e('Library scan progress stream error: $error');
      },
      cancelOnError: false,
    );

    try {
      final scanResult = (iosBookmark != null && iosBookmark.isNotEmpty)
          ? await PlatformBridge.scanSafTree(iosBookmark)
          : await PlatformBridge.scanLibraryFolder(libraryPath);

      await _db.replaceAll(scanResult);
      await refresh();

      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await writeLocalLibraryLastScannedAt(prefs, now);
      state = state.copyWith(lastScannedAt: now);
    } catch (e) {
      _log.e('Failed to start library scan: $e');
    } finally {
      await _scanProgressSubscription?.cancel();
      _scanProgressSubscription = null;
      state = state.copyWith(isScanning: false, scanIsFinalizing: false);
    }
  }

  Future<void> cancelScan() async {
    if (!state.isScanning) return;
    try {
      await PlatformBridge.cancelLibraryScan();
      state = state.copyWith(scanWasCancelled: true);
    } catch (e) {
      _log.e('Failed to cancel library scan: $e');
    } finally {
      await _scanProgressSubscription?.cancel();
      _scanProgressSubscription = null;
      state = state.copyWith(isScanning: false, scanIsFinalizing: false);
    }
  }

  Future<void> clearLibrary() async {
    await _db.clearAll();
    await refresh();
  }

  Future<int> cleanupMissingFiles(
    String libraryPath, {
    String? iosBookmark,
  }) async {
    final paths = await _scanLibraryFilePaths(libraryPath, iosBookmark: iosBookmark);
    final removed = await _db.cleanupMissingFiles(existingPaths: paths);
    await refresh();
    return removed;
  }

  Future<Set<String>> _scanLibraryFilePaths(
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

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

final localLibraryProvider = StateNotifierProvider<LocalLibraryNotifier, LocalLibraryState>((ref) {
  return LocalLibraryNotifier();
});

class LocalLibraryCoverRequest {
  final String? trackName;
  final String? artistName;
  final String? albumName;
  final String? isrc;

  const LocalLibraryCoverRequest({this.trackName, this.artistName, this.albumName, this.isrc});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalLibraryCoverRequest &&
          trackName == other.trackName &&
          artistName == other.artistName &&
          albumName == other.albumName &&
          isrc == other.isrc;

  @override
  int get hashCode => trackName.hashCode ^ artistName.hashCode ^ albumName.hashCode ^ isrc.hashCode;
}

class LocalLibraryCoverBatchRequest {
  final List<LocalLibraryCoverRequest> requests;
  const LocalLibraryCoverBatchRequest(this.requests);
}

final localLibraryCoverProvider = FutureProvider.family<String?, LocalLibraryCoverRequest>((ref, req) async {
  final db = LibraryDatabase.instance;
  LocalLibraryItem? item;
  if (req.isrc != null) item = await db.getByIsrc(req.isrc!);
  if (item == null && req.trackName != null && req.artistName != null) {
    item = await db.findFirstByTrackAndArtist(req.trackName!, req.artistName!);
  }
  return item?.coverPath;
});

final localLibraryFirstCoverProvider = FutureProvider.family<String?, LocalLibraryCoverBatchRequest>((ref, batch) async {
  final db = LibraryDatabase.instance;
  for (final req in batch.requests) {
    LocalLibraryItem? item;
    if (req.isrc != null) item = await db.getByIsrc(req.isrc!);
    if (item == null && req.trackName != null && req.artistName != null) {
      item = await db.findFirstByTrackAndArtist(req.trackName!, req.artistName!);
    }
    if (item?.coverPath != null) return item!.coverPath;
  }
  return null;
});
