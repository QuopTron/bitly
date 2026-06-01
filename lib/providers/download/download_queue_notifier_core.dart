part of 'package:bitly/providers/download/download_queue_provider.dart';

final downloadHistoryProvider = NotifierProvider<DownloadHistoryNotifier, DownloadHistoryState>(
  DownloadHistoryNotifier.new,
);
const _cleanupInterval = 50;
const _progressPollingInterval = Duration(milliseconds: 1200);
const _idleProgressPollEveryTicks = 3;
const _queueSchedulingInterval = Duration(milliseconds: 250);
const _queuePersistDebounceDuration = Duration(milliseconds: 350);
const _nativeWorkerRunIdPrefsKey =
    'download_queue_native_worker_run_id';
const _bytesUiStep = 104857; // ~0.1 MiB, matches one-decimal MB UI.
const _serviceProgressStepPercent = 2;

class DownloadQueueNotifier extends Notifier<DownloadQueueState> {
  Timer? _progressTimer;
  Timer? _progressStreamBootstrapTimer;
  Timer? _queuePersistDebounce;
  StreamSubscription<Map<String, dynamic>>? _progressStreamSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  int _downloadCount = 0;

  final AppStateDatabase _appStateDb = AppStateDatabase.instance;
  int _totalQueuedAtStart = 0;
  int _completedInSession = 0;
  int _failedInSession = 0;
  int _queueItemSequence = 0;
  bool _isLoaded = false;
  final Set<String> _ensuredDirs = {};
  int _progressPollingErrorCount = 0;
  bool _isProgressPollingInFlight = false;
  int _idleProgressPollTick = 0;
  bool _hasReceivedProgressStreamEvent = false;
  bool _usingProgressStream = false;
  bool _networkPausedByWifiOnly = false;
  String? _lastServiceTrackName;
  String? _lastServiceArtistName;
  String? _lastServiceStatus;
  int _lastServicePercent = -1;
  int _lastServiceQueueCount = -1;
  DateTime _lastServiceUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastFinalizingTrackName;
  String? _lastFinalizingArtistName;
  String? _lastNotifTrackName;
  String? _lastNotifArtistName;
  int _lastNotifPercent = -1;
  int _lastNotifQueueCount = -1;
  final Set<String> _locallyCancelledItemIds = {};
  final Set<String> _pausePendingItemIds = {};
  String? _activeNativeWorkerRunId;

  // Album ReplayGain accumulator: keyed by album identifier.
  // Stores per-track loudness data until all album tracks are done,
  // then computes and writes album gain/peak to every track in the album.
  final Map<String, _AlbumRgAccumulator> _albumRgData = {};

  double _normalizeProgressForUi(double value) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    if (clamped <= 0) return 0;
    if (clamped >= 1) return 1;
    final rounded = double.parse(clamped.toStringAsFixed(2));
    return rounded == 0 ? 0.01 : rounded;
  }

  double _normalizeSpeedForUi(double value) {
    if (value <= 0) return 0;
    return double.parse(value.toStringAsFixed(1));
  }

  int _normalizeBytesForUi(int value) {
    if (value <= 0) return 0;
    return (value ~/ _bytesUiStep) * _bytesUiStep;
  }

  bool _shouldUpdateProgressNotification({
    required String trackName,
    required String artistName,
    required int progress,
    required int total,
    required int queueCount,
  }) {
    final safeTotal = total > 0 ? total : 1;
    final percent = ((progress * 100) / safeTotal).round().clamp(0, 100);
    final changed =
        trackName != _lastNotifTrackName ||
        artistName != _lastNotifArtistName ||
        percent != _lastNotifPercent ||
        queueCount != _lastNotifQueueCount;
    if (!changed) {
      return false;
    }

    _lastNotifTrackName = trackName;
    _lastNotifArtistName = artistName;
    _lastNotifPercent = percent;
    _lastNotifQueueCount = queueCount;
    return true;
  }

  @override
  DownloadQueueState build() {
    ref.listen<AppSettings>(settingsProvider, (previous, next) {
      final previousConcurrent =
          previous?.concurrentDownloads ?? state.concurrentDownloads;
      updateSettings(next);
      if (previousConcurrent != next.concurrentDownloads) {
        _log.i(
          'Concurrent downloads updated: $previousConcurrent -> ${next.concurrentDownloads}',
        );
      }
      if (previous?.downloadNetworkMode != next.downloadNetworkMode) {
        _handleDownloadNetworkModeChanged(next.downloadNetworkMode);
      }
    });

    ref.onDispose(() {
      _progressTimer?.cancel();
      _progressStreamBootstrapTimer?.cancel();
      _progressStreamSub?.cancel();
      _connectivitySub?.cancel();
      _progressTimer = null;
      _progressStreamBootstrapTimer = null;
      _progressStreamSub = null;
      _connectivitySub = null;
      if (_queuePersistDebounce?.isActive == true) {
        _queuePersistDebounce?.cancel();
        unawaited(_flushQueueToStorage());
      } else {
        _queuePersistDebounce?.cancel();
      }
      _queuePersistDebounce = null;
    });

    Future.microtask(() async {
      updateSettings(ref.read(settingsProvider));
      await _initOutputDir();
      await _loadQueueFromStorage();
    });
    return const DownloadQueueState();
  }

  Future<void> _loadQueueFromStorage() async {
    if (_isLoaded) return;
    _isLoaded = true;

    try {
      final rows = await _appStateDb.getPendingDownloadQueueRows();
      if (rows.isEmpty) {
        _log.d('No queue found in storage');
        return;
      }

      final pendingItems = <DownloadItem>[];
      for (final row in rows) {
        final itemJson = row['item_json'] as String?;
        if (itemJson == null || itemJson.isEmpty) continue;


        try {
          final decoded = jsonDecode(itemJson);
          if (decoded is! Map) continue;
          var item = DownloadItem.fromJson(Map<String, dynamic>.from(decoded));
          final normalizedService = _normalizeQueuedService(item.service);
          if (normalizedService != item.service) {
            item = item.copyWith(service: normalizedService);
          }
          if (item.status == DownloadStatus.downloading ||
              item.status == DownloadStatus.finalizing) {
            item = item.copyWith(status: DownloadStatus.queued, progress: 0);
          }
          if (item.status == DownloadStatus.queued) {
            pendingItems.add(item);
          }
        } catch (e) {
          continue;
        }
      }

      if (pendingItems.isEmpty) {
        _log.d('No pending items to restore');
        await _appStateDb.replacePendingDownloadQueueRows(const []);
        return;
      }

      final normalizedPendingItems = _normalizeRestoredQueueIds(pendingItems);
      state = state.copyWith(items: normalizedPendingItems);
      _log.i(
        'Restored ${normalizedPendingItems.length} pending items from storage',
      );
      if (await _tryAdoptAndroidNativeWorkerSnapshot(normalizedPendingItems)) {
        return;
      }
      Future.microtask(() => _processQueue());
    } catch (e) {
      _log.e('Failed to load queue from storage: $e');
    }
  }

  void _saveQueueToStorage() {
    _queuePersistDebounce?.cancel();
    _queuePersistDebounce = Timer(_queuePersistDebounceDuration, () {
      _flushQueueToStorage();
    });
  }

  Future<void> _flushQueueToStorage() async {
    try {
      final pendingItems = state.items
          .where(
            (item) =>
                item.status == DownloadStatus.queued ||
                item.status == DownloadStatus.downloading ||
                item.status == DownloadStatus.finalizing,
          )
          .toList();

      if (pendingItems.isEmpty) {
        await _appStateDb.replacePendingDownloadQueueRows(const []);
        _log.d('Cleared queue storage (no pending items)');
      } else {
        final nowIso = DateTime.now().toIso8601String();
        final rows = pendingItems
            .map(
              (item) => <String, dynamic>{
                'id': item.id,
                'track_json': jsonEncode(item.track.toJson()),
                'item_json': jsonEncode(item.toJson()),
                'status': item.status.name,
                'created_at': item.createdAt.toIso8601String(),
                'updated_at': nowIso,
                'added_at': item.createdAt.toIso8601String(),
              },
            )
            .toList(growable: false);
        await _appStateDb.replacePendingDownloadQueueRows(rows);
        _log.d('Saved ${pendingItems.length} pending items to storage');
      }
    } catch (e) {
      _log.e('Failed to save queue to storage: $e');
    }
  }

  void _startMultiProgressPolling() {
    _progressTimer?.cancel();
    _progressStreamBootstrapTimer?.cancel();
    _progressStreamBootstrapTimer = null;
    _progressStreamSub?.cancel();
    _progressStreamSub = null;
    _hasReceivedProgressStreamEvent = false;
    _usingProgressStream = false;
    _idleProgressPollTick = 0;

    if (Platform.isAndroid || Platform.isIOS) {
      _attachDownloadProgressStream();
      return;
    }

    _startMultiProgressPollingTimer();
  }

  void _attachDownloadProgressStream() {
    _progressStreamSub?.cancel(); // Limpiar suscripción anterior
    _progressStreamSub = PlatformBridge.downloadProgressStream().listen(
      (allProgress) {
        _hasReceivedProgressStreamEvent = true;
        _usingProgressStream = true;
        _progressStreamBootstrapTimer?.cancel();
        _progressStreamBootstrapTimer = null;
        if (_isProgressPollingInFlight) return;
        _isProgressPollingInFlight = true;
        try {
          _processAllDownloadProgress(allProgress);
          _progressPollingErrorCount = 0;
        } catch (e) {
          _progressPollingErrorCount++;
          if (_progressPollingErrorCount <= 3) {
            _log.w('Progress stream processing failed: $e');
          }
        } finally {
          _isProgressPollingInFlight = false;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_usingProgressStream) {
          _log.w(
            'Download progress stream failed, fallback to polling: $error',
          );
        }
        _progressStreamSub?.cancel();
        _progressStreamSub = null;
        _usingProgressStream = false;
        _progressStreamBootstrapTimer?.cancel();
        _progressStreamBootstrapTimer = null;
        _startMultiProgressPollingTimer();
      },
      cancelOnError: false,
    );

    _progressStreamBootstrapTimer = Timer(const Duration(seconds: 3), () {
      if (_hasReceivedProgressStreamEvent) {
        return;
      }
      _log.w('Download progress stream timeout, fallback to polling');
      _progressStreamSub?.cancel();
      _progressStreamSub = null;
      _usingProgressStream = false;
      _startMultiProgressPollingTimer();
    });
  }

  void _startMultiProgressPollingTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(_progressPollingInterval, (timer) async {
      if (_isProgressPollingInFlight) return;
      _isProgressPollingInFlight = true;
      try {
        final currentItems = state.items;
        final hasQueuedItems = currentItems.any(
          (item) => item.status == DownloadStatus.queued,
        );
        final hasActiveItems = currentItems.any(
          (item) =>
              item.status == DownloadStatus.downloading ||
              item.status == DownloadStatus.finalizing,
        );

        if (!hasActiveItems) {
          if (state.isPaused || !hasQueuedItems) {
            _idleProgressPollTick = 0;
            return;
          }

          _idleProgressPollTick =
              (_idleProgressPollTick + 1) % _idleProgressPollEveryTicks;
          if (_idleProgressPollTick != 0) {
            return;
          }
        } else {
          _idleProgressPollTick = 0;
        }

        final allProgress = await PlatformBridge.getAllDownloadProgress();
        _processAllDownloadProgress(allProgress);
        _progressPollingErrorCount = 0;
      } catch (e) {
        _progressPollingErrorCount++;
        if (_progressPollingErrorCount <= 3) {
          _log.w('Progress polling failed: $e');
        }
      } finally {
        _isProgressPollingInFlight = false;
      }
    });
  }

  void _processAllDownloadProgress(Map<String, dynamic> allProgress) {
    final rawItems = allProgress['items'];
    final items = rawItems is Map
        ? rawItems.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    final currentItems = state.items;
    final lookup = state.lookup;
    int queuedCount = 0;
    int downloadingCount = 0;
    DownloadItem? firstDownloading;
    bool hasFinalizingItem = false;
    String? finalizingTrackName;
    String? finalizingArtistName;
    for (int i = 0; i < currentItems.length; i++) {
      final item = currentItems[i];
      if (item.status == DownloadStatus.downloading) {
        downloadingCount++;
        firstDownloading ??= item;
      }
      if (item.status == DownloadStatus.queued ||
          item.status == DownloadStatus.downloading ||
          item.status == DownloadStatus.finalizing) {
        queuedCount++;
      }
      if (item.status == DownloadStatus.finalizing && !hasFinalizingItem) {
        hasFinalizingItem = true;
        finalizingTrackName = item.track.name;
        finalizingArtistName = item.track.artistName;
      }
    }
    final progressUpdates = <String, _ProgressUpdate>{};

    for (final entry in items.entries) {
      final itemId = entry.key;
      final localItem = lookup.byItemId[itemId];
      if (localItem == null) {
        continue;
      }
      if (_isPausePending(itemId)) {
        PlatformBridge.clearItemProgress(itemId).catchError((e) {});
        continue;
      }
      if (localItem.status == DownloadStatus.skipped) {
        PlatformBridge.clearItemProgress(itemId).catchError((e) {});
        continue;
      }
      if (localItem.status == DownloadStatus.completed ||
          localItem.status == DownloadStatus.failed) {
        continue;
      }
      if (localItem.status == DownloadStatus.finalizing) {
        PlatformBridge.clearItemProgress(itemId).catchError((e) {});
        hasFinalizingItem = true;
        finalizingTrackName = localItem.track.name;
        finalizingArtistName = localItem.track.artistName;
        continue;
      }
      final rawItemProgress = entry.value;
      if (rawItemProgress is! Map) {
        continue;
      }
      final itemProgress = Map<String, dynamic>.from(rawItemProgress);
      final bytesReceived =
          (itemProgress['bytes_received'] as num?)?.toInt() ?? 0;
      final bytesTotal = (itemProgress['bytes_total'] as num?)?.toInt() ?? 0;
      final speedMBps = (itemProgress['speed_mbps'] as num?)?.toDouble() ?? 0.0;
      final isDownloading = itemProgress['is_downloading'] as bool? ?? false;
      final status = itemProgress['status'] as String? ?? 'downloading';
      final progressFromBackend =
          (itemProgress['progress'] as num?)?.toDouble() ?? 0.0;
      final hasRealProgress =
          status != 'preparing' &&
          (bytesReceived > 0 || bytesTotal > 0 || progressFromBackend > 0);

      if (status == 'finalizing') {
        progressUpdates[itemId] = const _ProgressUpdate(
          status: DownloadStatus.finalizing,
          progress: 1.0,
        );
        hasFinalizingItem = true;
        finalizingTrackName = localItem.track.name;
        finalizingArtistName = localItem.track.artistName;
        continue;
      }

      if (status == 'preparing') {
        progressUpdates[itemId] = const _ProgressUpdate(
          status: DownloadStatus.downloading,
          progress: 0.0,
          speedMBps: 0,
          bytesReceived: 0,
          bytesTotal: 0,
        );

        if (LogBuffer.loggingEnabled) {
          _log.d('Preparing [$itemId]: waiting for real download bytes');
        }
        continue;
      }

      if (isDownloading || hasRealProgress) {
        double percentage = 0.0;

        if (bytesTotal > 0) {
          percentage = bytesReceived / bytesTotal;
        } else {
          percentage = progressFromBackend;
        }
        final normalizedProgress = _normalizeProgressForUi(percentage);
        final normalizedSpeed = _normalizeSpeedForUi(speedMBps);
        final normalizedBytes = _normalizeBytesForUi(bytesReceived);

        progressUpdates[itemId] = _ProgressUpdate(
          status: DownloadStatus.downloading,
          progress: normalizedProgress,
          speedMBps: normalizedSpeed,
          bytesReceived: normalizedBytes,
          bytesTotal: bytesTotal,
        );

        if (LogBuffer.loggingEnabled) {
          final mbReceived = bytesReceived / (1024 * 1024);
          final mbTotal = bytesTotal / (1024 * 1024);
          if (bytesTotal > 0) {
            _log.d(
              'Progress [$itemId]: ${(percentage * 100).toStringAsFixed(1)}% (${mbReceived.toStringAsFixed(2)}/${mbTotal.toStringAsFixed(2)} MB) @ ${speedMBps.toStringAsFixed(2)} MB/s',
            );
          } else {
            _log.d(
              'Progress [$itemId]: ${(percentage * 100).toStringAsFixed(1)}% (DASH segments/unknown size) @ ${speedMBps.toStringAsFixed(2)} MB/s',
            );
          }
        }
      }
    }

    if (progressUpdates.isNotEmpty) {
      var updatedItems = currentItems;
      bool changed = false;
      final changedIndices = <int>[];

      for (final entry in progressUpdates.entries) {
        final index = lookup.indexByItemId[entry.key];
        if (index == null) continue;
        final current = updatedItems[index];
        if (current.status == DownloadStatus.skipped ||
            current.status == DownloadStatus.completed ||
            current.status == DownloadStatus.failed) {
          continue;
        }
        final update = entry.value;
        if (current.status == DownloadStatus.finalizing &&
            update.status != DownloadStatus.finalizing) {
          continue;
        }
        final next = current.copyWith(
          status: update.status,
          progress: update.progress,
          speedMBps: update.speedMBps ?? current.speedMBps,
          bytesReceived: update.bytesReceived ?? current.bytesReceived,
          bytesTotal: update.bytesTotal ?? current.bytesTotal,
        );
        if (current.status != next.status ||
            current.progress != next.progress ||
            current.speedMBps != next.speedMBps ||
            current.bytesReceived != next.bytesReceived ||
            current.bytesTotal != next.bytesTotal) {
          if (!changed) {
            updatedItems = List<DownloadItem>.from(updatedItems);
            changed = true;
          }
          updatedItems[index] = next;
          changedIndices.add(index);
        }
      }

      if (changed) {
        state = state.copyWith(
          items: updatedItems,
          lookup: state.lookup.updatedForIndices(
            previousItems: currentItems,
            nextItems: updatedItems,
            changedIndices: changedIndices,
          ),
        );
      }
    }

    if (hasFinalizingItem && finalizingTrackName != null) {
      final safeArtistName = finalizingArtistName ?? '';
      if (Platform.isAndroid) {
        _maybeUpdateAndroidDownloadService(
          trackName: finalizingTrackName,
          artistName: NotificationDownload.embeddingMetadataLabel,
          progress: 100,
          total: 100,
          queueCount: queuedCount,
          status: 'finalizing',
        );
      } else if (finalizingTrackName != _lastFinalizingTrackName ||
          safeArtistName != _lastFinalizingArtistName) {
        NotificationDownload.showFinalizing(
          trackName: finalizingTrackName,
          artistName: safeArtistName,
        );
        _lastFinalizingTrackName = finalizingTrackName;
        _lastFinalizingArtistName = safeArtistName;
      }
      return;
    }
    _lastFinalizingTrackName = null;
    _lastFinalizingArtistName = null;

    if (items.isNotEmpty) {
      if (downloadingCount > 0 && firstDownloading != null) {
        final rawProgress = items[firstDownloading.id];
        if (rawProgress is! Map) {
          return;
        }
        final selectedProgress = Map<String, dynamic>.from(rawProgress);
        final bytesReceived =
            (selectedProgress['bytes_received'] as num?)?.toInt() ?? 0;
        final bytesTotal =
            (selectedProgress['bytes_total'] as num?)?.toInt() ?? 0;
        final backendStatus =
            selectedProgress['status'] as String? ?? 'downloading';
        final trackName = downloadingCount == 1
            ? firstDownloading.track.name
            : '$downloadingCount downloads';
        final artistName = downloadingCount == 1
            ? firstDownloading.track.artistName
            : 'Downloading...';

        int notifProgress = bytesReceived;
        int notifTotal = bytesTotal;

        final progressPercent =
            (selectedProgress['progress'] as num?)?.toDouble() ?? 0.0;
        if (backendStatus == 'preparing') {
          notifProgress = 0;
          notifTotal = 0;
        } else if (bytesTotal <= 0) {
          notifProgress = (progressPercent * 100).toInt();
          notifTotal = 100;
        }
        final serviceStatus = notifTotal <= 0 ? 'preparing' : 'downloading';

        if (!Platform.isAndroid &&
            _shouldUpdateProgressNotification(
              trackName: trackName,
              artistName: artistName,
              progress: notifProgress,
              total: notifTotal,
              queueCount: queuedCount,
            )) {
          final safeNotifTotal = notifTotal > 0 ? notifTotal : 1;
          NotificationDownload.showProgress(
            trackName: trackName,
            artistName: artistName,
            progress: notifProgress,
            total: safeNotifTotal,
          );
        }

        if (Platform.isAndroid) {
          _maybeUpdateAndroidDownloadService(
            trackName: firstDownloading.track.name,
            artistName: firstDownloading.track.artistName,
            progress: notifProgress,
            total: notifTotal,
            queueCount: queuedCount,
            status: serviceStatus,
          );
        }
      }
    }
  }

  void _maybeUpdateAndroidDownloadService({
    required String trackName,
    required String artistName,
    required int progress,
    required int total,
    required int queueCount,
    String status = 'downloading',
  }) {
    final now = DateTime.now();
    final progressBucket = total <= 0
        ? -1
        : (() {
            final progressPercent = ((progress * 100) / total)
                .round()
                .clamp(0, 100)
                .toInt();
            return progressPercent == 100
                ? 100
                : ((progressPercent ~/ _serviceProgressStepPercent) *
                          _serviceProgressStepPercent)
                      .clamp(0, 100)
                      .toInt();
          })();

    final didContentChange =
        trackName != _lastServiceTrackName ||
        artistName != _lastServiceArtistName ||
        status != _lastServiceStatus ||
        queueCount != _lastServiceQueueCount ||
        progressBucket != _lastServicePercent;
    final allowHeartbeat =
        now.difference(_lastServiceUpdateAt) >= const Duration(seconds: 5);

    if (!didContentChange && !allowHeartbeat) {
      return;
    }

    _lastServiceTrackName = trackName;
    _lastServiceArtistName = artistName;
    _lastServiceStatus = status;
    _lastServicePercent = progressBucket;
    _lastServiceQueueCount = queueCount;
    _lastServiceUpdateAt = now;

    PlatformBridge.updateDownloadServiceProgress(
      trackName: trackName,
      artistName: artistName,
      progress: progress,
      total: total,
      queueCount: queueCount,
      status: status,
    ).catchError((e) {});
  }

  void _stopProgressPolling() {
    _progressTimer?.cancel();
    _progressStreamBootstrapTimer?.cancel();
    _progressStreamSub?.cancel();
    _progressTimer = null;
    _progressStreamBootstrapTimer = null;
    _progressStreamSub = null;
    _progressPollingErrorCount = 0;
    _isProgressPollingInFlight = false;
    _idleProgressPollTick = 0;
    _hasReceivedProgressStreamEvent = false;
    _usingProgressStream = false;
    _lastServiceTrackName = null;
    _lastServiceArtistName = null;
    _lastServiceStatus = null;
    _lastServicePercent = -1;
    _lastServiceQueueCount = -1;
    _lastServiceUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastFinalizingTrackName = null;
    _lastFinalizingArtistName = null;
    _lastNotifTrackName = null;
    _lastNotifArtistName = null;
    _lastNotifPercent = -1;
    _lastNotifQueueCount = -1;
  }

  Directory _defaultDocumentsOutputDir(String documentsPath) {
    return Directory('$documentsPath/$_defaultOutputFolderName');
  }

  Directory _defaultAndroidMusicOutputDir(String storageRootPath) {
    return Directory('$storageRootPath/$_defaultAndroidMusicSubpath');
  }

  Future<Directory> _ensureDefaultDocumentsOutputDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final musicDir = _defaultDocumentsOutputDir(dir.path);
    if (!await musicDir.exists()) {
      await musicDir.create(recursive: true);
    }
    return musicDir;
  }

  Future<Directory?> _ensureDefaultAndroidMusicOutputDir() async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) return null;

    final musicDir = _defaultAndroidMusicOutputDir(
      dir.parent.parent.parent.parent.path,
    );
    if (!await musicDir.exists()) {
      await musicDir.create(recursive: true);
    }
    return musicDir;
  }

  Future<void> _initOutputDir() async {
    if (state.outputDir.isEmpty) {
      try {
        if (Platform.isIOS) {
          final musicDir = await _ensureDefaultDocumentsOutputDir();
          state = state.copyWith(outputDir: musicDir.path);
        } else {
          final musicDir =
              await _ensureDefaultAndroidMusicOutputDir() ??
              await _ensureDefaultDocumentsOutputDir();
          state = state.copyWith(outputDir: musicDir.path);
        }
      } catch (e) {
        final musicDir = await _ensureDefaultDocumentsOutputDir();
        state = state.copyWith(outputDir: musicDir.path);

      }
    }
  }

  Future<void> _ensureDirExists(String path, {String? label}) async {
    if (_ensuredDirs.contains(path)) return;
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      if (label != null) {
        _log.d('Created $label: $path');
      } else {
        _log.d('Created folder: $path');
      }
    }
    _ensuredDirs.add(path);
  }

  void setOutputDir(String dir) {
    state = state.copyWith(outputDir: dir);
  }

  Future<String> _buildOutputDir(Track track, {String? playlistName}) async {
    final baseDir = state.outputDir;
    final folderArtist = _sanitizeFolderName(
      primaryArtistName(normalizeOptionalString(track.albumArtist) ?? track.artistName),
    );
    final folderTrack = _sanitizeFolderName(track.name);
    if (playlistName != null && playlistName.isNotEmpty) {
      final playlistFolder = _sanitizeFolderName(playlistName);
      final fullPath = '$baseDir${Platform.pathSeparator}$folderArtist${Platform.pathSeparator}$playlistFolder${Platform.pathSeparator}$folderTrack';
      await _ensureDirExists(fullPath, label: 'Playlist folder');
      return fullPath;
    }
    final albumName = _sanitizeFolderName(track.albumName);
    if (albumName == 'Unknown' || albumName.isEmpty) {
      final fullPath = '$baseDir${Platform.pathSeparator}$folderArtist${Platform.pathSeparator}$folderTrack';
      await _ensureDirExists(fullPath);
      return fullPath;
    }
    final fullPath = '$baseDir${Platform.pathSeparator}$folderArtist${Platform.pathSeparator}$albumName${Platform.pathSeparator}$folderTrack';
    await _ensureDirExists(fullPath);
    return fullPath;
  }

  String _sanitizeFolderName(String name) {
    final buffer = StringBuffer();
    for (final rune in name.runes) {
      if (rune < 0x20 || rune == 0x7f) {
        continue;
      }
      final char = String.fromCharCode(rune);
      if (_invalidFolderChars.hasMatch(char)) {
        buffer.write(' ');
        continue;
      }
      buffer.write(char);
    }

    var sanitized = buffer.toString().trim();
    sanitized = sanitized.replaceAll(_trimDotsAndSpacesRegex, '');
    sanitized = sanitized.replaceAll(_multiWhitespaceRegex, ' ');
    sanitized = sanitized.replaceAll(_multiUnderscoreRegex, '_');
    sanitized = sanitized.replaceAll(_trimUnderscoresAndSpacesRegex, '');

    if (sanitized.isEmpty) {
      return 'Unknown';
    }
    return sanitized;
  }

  String _truncateUtf8Bytes(String value, int maxBytes) {
    if (maxBytes <= 0 || utf8.encode(value).length <= maxBytes) {
      return value;
    }

    final buffer = StringBuffer();
    var usedBytes = 0;
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final charBytes = utf8.encode(char).length;
      if (usedBytes + charBytes > maxBytes) break;
      buffer.write(char);
      usedBytes += charBytes;
    }
    return buffer.toString();
  }

  String _trimSafeName(String value) {
    var trimmed = value.trim();
    trimmed = trimmed.replaceAll(_trimDotsAndSpacesRegex, '');
    trimmed = trimmed.replaceAll(_trimUnderscoresAndSpacesRegex, '');
    return trimmed.isEmpty ? 'Unknown' : trimmed;
  }

  String _sanitizeSafRelativeDir(String relativeDir) {
    if (relativeDir.trim().isEmpty) return '';
    final parts = relativeDir
        .split('/')
        .map(_sanitizeFolderName)
        .map((part) {
          final truncated = _truncateUtf8Bytes(
            part,
            _maxSafDirSegmentUtf8Bytes,
          );
          return _trimSafeName(truncated);
        })
        .where((part) => part.isNotEmpty && part != '.' && part != '..')
        .toList(growable: false);
    return parts.join('/');
  }

  Future<String> _buildSafFileName(String baseName, String outputExt) async {
    final sanitized = await PlatformBridge.sanitizeFilename(baseName);
    final extBytes = utf8.encode(outputExt).length;
    final maxBaseBytes = max(1, _maxSafFilenameUtf8Bytes - extBytes);
    final truncated = _truncateUtf8Bytes(sanitized, maxBaseBytes);
    return '${_trimSafeName(truncated)}$outputExt';
  }

  String? _resolveAlbumArtistForMetadata(Track track, AppSettings settings) {
    return normalizeOptionalString(track.albumArtist);
  }

  bool _isSafMode(AppSettings settings) {
    return Platform.isAndroid &&
        settings.storageMode == 'saf' &&
        settings.downloadTreeUri.isNotEmpty;
  }

  bool _isSafWriteFailure(Map<String, dynamic> result) {
    final error = (result['error'] ?? result['message'] ?? '')
        .toString()
        .toLowerCase();
    if (error.isEmpty) return false;
    return error.contains('saf') ||
        error.contains('content uri') ||
        error.contains('permission denied') ||
        error.contains('documentfile');
  }

  Future<String> _buildRelativeOutputDir(Track track, {String? playlistName}) async {
    final folderArtist = _sanitizeFolderName(
      primaryArtistName(normalizeOptionalString(track.albumArtist) ?? track.artistName),
    );
    final folderTrack = _sanitizeFolderName(track.name);
    if (playlistName != null && playlistName.isNotEmpty) {
      final playlistFolder = _sanitizeFolderName(playlistName);
      return '$folderArtist/$playlistFolder/$folderTrack';
    }
    final albumName = _sanitizeFolderName(track.albumName);
    if (albumName == 'Unknown' || albumName.isEmpty) {
      return '$folderArtist/$folderTrack';
    }
    return '$folderArtist/$albumName/$folderTrack';
  }
}

