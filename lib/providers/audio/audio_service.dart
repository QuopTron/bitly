// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

part of 'audio_player_provider.dart';

extension AudioServiceExtension on AudioPlayerNotifier {
  Future<String?> _findLocalTrack(
    String trackId, String trackName, String artistName, String? isrc,
  ) async {
    final candidates = <String?>{trackId, 'spotify:track:$trackId'};
    if (isrc != null && isrc.isNotEmpty) candidates.add(isrc);

    for (final id in candidates) {
      if (id == null || id.isEmpty) continue;
      var json = await HistoryDatabase.instance.getBySpotifyId(id);
      if (json == null && isrc != null && isrc.isNotEmpty) {
        json = await HistoryDatabase.instance.getByIsrc(isrc);
      }
      if (json != null) {
        final item = DownloadHistoryItem.fromJson(json);
        if (await fileExists(item.filePath)) return item.filePath;
      }
    }

    final json = await HistoryDatabase.instance.findByTrackAndArtist(trackName, artistName);
    if (json != null) {
      final item = DownloadHistoryItem.fromJson(json);
      if (await fileExists(item.filePath)) return item.filePath;
    }

    return null;
  }

  Future<String?> _findLocalCover(String audioPath) async {
    try {
      final dir = audioPath.substring(0, audioPath.lastIndexOf(Platform.pathSeparator));
      final baseName = audioPath.substring(audioPath.lastIndexOf(Platform.pathSeparator) + 1);
      final nameWithoutExt = baseName.replaceFirst(RegExp(r'\.[^.]+$'), '');

      final candidates = [
        '$dir${Platform.pathSeparator}cover.jpg',
        '$dir${Platform.pathSeparator}cover.png',
        '$dir${Platform.pathSeparator}$nameWithoutExt.jpg',
        '$dir${Platform.pathSeparator}$nameWithoutExt.png',
        '$dir${Platform.pathSeparator}${nameWithoutExt}_cover.jpg',
        '$dir${Platform.pathSeparator}${nameWithoutExt}_cover.png',
        '$dir${Platform.pathSeparator}Folder.jpg',
        '$dir${Platform.pathSeparator}folder.jpg',
      ];
      for (final c in candidates) {
        if (await fileExists(c)) return c;
      }
    } catch (e) {}
    return null;
  }

  Future<void> _downloadAndPlay(
    String trackId, String trackName, String artistName,
    String provider, String? isrc, String? quality,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final safeId = trackId.replaceAll(RegExp(r'[^\w]'), '_');

      final payload = DownloadRequestPayload(
        trackName: trackName,
        artistName: artistName,
        albumName: '',
        outputDir: tempDir.path,
        filenameFormat: 'play_$safeId',
        isrc: isrc ?? '',
        service: provider,
        source: provider,
        itemId: trackId,
        useExtensions: true,
        useFallback: true,
        isPremium: ref.read(settingsProvider).isPremium,
        premiumUntil: ref.read(settingsProvider).premiumUntil,
      );

      state = state.copyWith(downloadProgress: 50);
      _log.i('Downloading for playback: $trackName by $artistName via $provider');

      final result = await PlatformBridge.downloadByStrategy(payload: payload);
      final success = result['success'] == true;
      final filePath = result['file_path'] as String? ?? '';

      final file = File(filePath);
      if (success && filePath.isNotEmpty && await file.exists()) {
        final fileSize = await file.length();
        _log.i('Playback ready: $filePath ($fileSize bytes)');
        await _playFile(filePath);
      } else {
        _log.e('Playback download failed: ${result['error']}');
        state = state.copyWith(isLoading: false, isDownloading: false);
      }
    } on TimeoutException {
      _log.e('Playback download timed out for: $trackName by $artistName');
      state = state.copyWith(isLoading: false, isDownloading: false);
    } catch (e) {
      _log.e('Playback failed: $e');
      state = state.copyWith(isLoading: false, isDownloading: false);
    }
  }

  Future<void> _logPlayIfQualified() async {
    if (_playLoggedForCurrentTrack) return;
    final s = state;
    if (s.trackId == null || s.trackId == 'unknown') return;
    final position = s.position.inSeconds;
    const minSeconds = 30;
    if (position < minSeconds) return;
    _playLoggedForCurrentTrack = true;
    final durationSeconds = s.duration.inSeconds > 0 ? s.duration.inSeconds : null;
    try {
      await StatsDatabase.instance.logPlay(
        trackId: s.trackId ?? 'unknown',
        trackName: s.trackName ?? 'Unknown',
        artistName: s.artistName ?? 'Unknown',
        albumName: s.albumName,
        coverUrl: s.coverUrl,
        source: s.source,
        durationSeconds: durationSeconds,
      );
      ref.invalidate(achievementProgressProvider);
    } catch (e) {
      _log.w('Failed to log partial play stats: $e');
    }
    try {
      await _updateSecretStats();
    } catch (e) {}
  }

  Future<void> _updateSecretStats() async {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 5) {
    }
  }
}
