part of 'package:bitly/providers/settings/settings_provider.dart';

extension on SettingsNotifier {
  Future<void> _normalizeIosDownloadDirectoryIfNeeded() async {
    if (!Platform.isIOS) return;

    final currentDir = state.downloadDirectory.trim();
    if (currentDir.isEmpty) return;

    final normalizedDir = await validateOrFixIosPath(currentDir);
    if (normalizedDir == currentDir) return;

    settingsLog.i('Normalized iOS download directory: $currentDir -> $normalizedDir');
    state = state.copyWith(
      downloadDirectory: normalizedDir,
      downloadDirectoryBookmark: '',
    );
    await saveSettings();
  }

  Future<void> _normalizeSongLinkRegionIfNeeded() async {
    final normalized = normalizeSongLinkRegion(state.songLinkRegion);
    if (normalized == state.songLinkRegion) return;
    state = state.copyWith(songLinkRegion: normalized);
    await saveSettings();
  }

  Future<void> _cleanupRetiredSpotifySettings() async {
    try {
      final storedSecret = await _secureStorage.read(
        key: spotifyClientSecretKey,
      );
      if (storedSecret != null && storedSecret.isNotEmpty) {
        await _secureStorage.delete(key: spotifyClientSecretKey);
      }
    } catch (e) {
      settingsLog.w('Failed to cleanup retired Spotify settings: $e');
    }
  }
}
