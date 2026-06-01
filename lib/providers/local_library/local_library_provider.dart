import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:bitly/providers/local_library/local_library_service.dart';
import 'package:bitly/providers/local_library/local_library_state.dart';
import 'package:bitly/services/library/library_database.dart';
import 'package:bitly/utils/logger.dart';

export 'package:bitly/providers/local_library/local_library_state.dart';

final _log = AppLogger('LocalLibraryProvider');

class LocalLibraryNotifier extends StateNotifier<LocalLibraryState> {
  final _service = LocalLibraryService();
  StreamSubscription<Map<String, dynamic>>? _scanProgressSubscription;

  LocalLibraryNotifier() : super(const LocalLibraryState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final tracks = await _service.getAllTracks();
      final albums = await _service.getAlbums();
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
    await _service.removeItem(id);
    await refresh();
  }

  void bumpVersion() {
    state = state.copyWith(loadedIndexVersion: state.loadedIndexVersion + 1);
  }

  Future<void> updateItem(LocalLibraryItem item) async {
    await _service.updateItem(item);
    await refresh();
  }

  Future<LocalLibraryItem?> getById(String id) async {
    return await _service.getById(id);
  }

  Future<LocalLibraryItem?> getByIsrcAsync(String isrc) async {
    return await _service.getByIsrc(isrc);
  }

  Future<LocalLibraryItem?> findByTrackAndArtistAsync(String trackName, String artistName) async {
    return await _service.findByTrackAndArtist(trackName, artistName);
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
    return await _service.search(query);
  }

  Future<int> getCount() async {
    return await _service.getCount();
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
    _scanProgressSubscription = _service.listenToScanProgress(
      onData: (payload) {
        state = state.copyWith(
          scanProgress: LocalLibraryService.parseDouble(payload['scanProgress']) ?? state.scanProgress,
          scanCurrentFile: payload['scanCurrentFile'] as String?,
          scanTotalFiles: LocalLibraryService.parseInt(payload['scanTotalFiles']) ?? state.scanTotalFiles,
          scannedFiles: LocalLibraryService.parseInt(payload['scannedFiles']) ?? state.scannedFiles,
          excludedDownloadedCount: LocalLibraryService.parseInt(payload['excludedDownloadedCount']) ?? state.excludedDownloadedCount,
          scanIsFinalizing: payload['scanIsFinalizing'] == true,
        );
      },
      onError: (error) {
        _log.e('Library scan progress stream error: $error');
      },
    );

    try {
      final scanResult = await _service.performScan(libraryPath, iosBookmark: iosBookmark);
      await _service.replaceAll(scanResult);
      await refresh();
      await _service.saveLastScanTime();
      state = state.copyWith(lastScannedAt: DateTime.now());
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
      await _service.cancelScan();
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
    await _service.clearAll();
    await refresh();
  }

  Future<int> cleanupMissingFiles(
    String libraryPath, {
    String? iosBookmark,
  }) async {
    final paths = await _service.scanFilePaths(libraryPath, iosBookmark: iosBookmark);
    final removed = await _service.cleanupMissingFiles(paths);
    await refresh();
    return removed;
  }
}

final localLibraryProvider = StateNotifierProvider<LocalLibraryNotifier, LocalLibraryState>((ref) {
  return LocalLibraryNotifier();
});