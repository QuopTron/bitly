import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/providers/settings/settings_state.dart';
import 'package:bitly/providers/library/library_collections_provider.dart';
import 'package:bitly/models/settings/settings_copy.dart';
import 'package:bitly/utils/artist_utils.dart';

extension SettingsDownloadsExtension on SettingsNotifier {
  void setDownloadDirectory(String directory, {String? iosBookmark}) {
    final oldDirectory = state.downloadDirectory;
    state = state.copyWith(
      downloadDirectory: directory,
      downloadDirectoryBookmark: iosBookmark ?? '',
    );
    saveSettings();
    if (oldDirectory.isNotEmpty && oldDirectory != directory) {
      Future.microtask(() async {
        final collectionsNotifier = ref.read(libraryCollectionsProvider.notifier);
        await collectionsNotifier.migratePathsToNewDirectory(directory);
      });
    }
  }

  void setStorageMode(String mode) {
    final normalized = mode == 'saf' ? 'saf' : 'app';
    state = state.copyWith(storageMode: normalized);
    saveSettings();
  }

  void setDownloadTreeUri(String uri, {String? displayName}) {
    final nextDisplay = displayName ?? state.downloadDirectory;
    state = state.copyWith(
      downloadTreeUri: uri,
      storageMode: uri.isNotEmpty ? 'saf' : state.storageMode,
      downloadDirectory: nextDisplay,
      downloadDirectoryBookmark: uri.isNotEmpty
          ? ''
          : state.downloadDirectoryBookmark,
    );
    saveSettings();
  }

  void setConcurrentDownloads(int count) {
    final clamped = count.clamp(1, 4);
    if (state.concurrentDownloads != clamped) {
      state = state.copyWith(concurrentDownloads: clamped);
      saveSettings();
    }
  }

  void setAskQualityBeforeDownload(bool enabled) {
    state = state.copyWith(askQualityBeforeDownload: enabled);
    saveSettings();
  }

  void setNativeDownloadWorkerEnabled(bool enabled) {
    state = state.copyWith(nativeDownloadWorkerEnabled: enabled);
    saveSettings();
  }

  void setLocalLibraryEnabled(bool enabled) {
    state = state.copyWith(localLibraryEnabled: enabled);
    saveSettings();
  }

  void setLocalLibraryPath(String path) {
    state = state.copyWith(localLibraryPath: path);
    saveSettings();
  }

  void setLocalLibraryBookmark(String bookmark) {
    state = state.copyWith(localLibraryBookmark: bookmark);
    saveSettings();
  }

  void setLocalLibraryPathAndBookmark(String path, String bookmark) {
    state = state.copyWith(
      localLibraryPath: path,
      localLibraryBookmark: bookmark,
    );
    saveSettings();
  }

  void setLocalLibraryShowDuplicates(bool show) {
    state = state.copyWith(localLibraryShowDuplicates: show);
    saveSettings();
  }

  void setLocalLibraryAutoScan(String mode) {
    state = state.copyWith(localLibraryAutoScan: mode);
    saveSettings();
  }

  void setDeduplicateDownloads(bool enabled) {
    state = state.copyWith(deduplicateDownloads: enabled);
    saveSettings();
  }

  void setAutoExportFailedDownloads(bool enabled) {
    state = state.copyWith(autoExportFailedDownloads: enabled);
    saveSettings();
  }

  void setDownloadNetworkMode(String mode) {
    state = state.copyWith(downloadNetworkMode: mode);
    saveSettings();
  }

  void setUseAllFilesAccess(bool enabled) {
    state = state.copyWith(useAllFilesAccess: enabled);
    saveSettings();
  }
}