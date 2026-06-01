import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/providers/settings/settings_state.dart';
import 'package:bitly/providers/library/library_collections_provider.dart';
import 'package:bitly/models/settings/settings_copy.dart';
import 'package:bitly/utils/artist_utils.dart';

extension SettingsLibraryExtension on SettingsNotifier {
  void setFilenameFormat(String format) {
    state = state.copyWith(filenameFormat: format);
    saveSettings();
  }

  void setAutoFallback(bool enabled) {
    state = state.copyWith(autoFallback: enabled);
    saveSettings();
  }

  void setEmbedLyrics(bool enabled) {
    state = state.copyWith(embedLyrics: enabled);
    saveSettings();
  }

  void setEmbedMetadata(bool enabled) {
    state = state.copyWith(embedMetadata: enabled);
    saveSettings();
  }

  void setArtistTagMode(String mode) {
    if (mode == artistTagModeJoined || mode == artistTagModeSplitVorbis) {
      state = state.copyWith(artistTagMode: mode);
      saveSettings();
    }
  }

  void setLyricsMode(String mode) {
    if (mode == 'embed' || mode == 'external' || mode == 'both') {
      state = state.copyWith(lyricsMode: mode);
      saveSettings();
    }
  }

  void setLyricsProviders(List<String> providers) {
    state = state.copyWith(lyricsProviders: providers);
    saveSettings();
    syncLyricsSettingsToBackend();
  }

  void setLyricsIncludeTranslationNetease(bool enabled) {
    state = state.copyWith(lyricsIncludeTranslationNetease: enabled);
    saveSettings();
    syncLyricsSettingsToBackend();
  }

  void setLyricsIncludeRomanizationNetease(bool enabled) {
    state = state.copyWith(lyricsIncludeRomanizationNetease: enabled);
    saveSettings();
    syncLyricsSettingsToBackend();
  }

  void setLyricsMultiPersonWordByWord(bool enabled) {
    state = state.copyWith(lyricsMultiPersonWordByWord: enabled);
    saveSettings();
    syncLyricsSettingsToBackend();
  }

  void setMusixmatchLanguage(String languageCode) {
    state = state.copyWith(
      musixmatchLanguage: languageCode.trim().toLowerCase(),
    );
    saveSettings();
    syncLyricsSettingsToBackend();
  }

  void setLyricsAppleElrcWordSync(bool enabled) {
    state = state.copyWith(lyricsAppleElrcWordSync: enabled);
    saveSettings();
    syncLyricsSettingsToBackend();
  }

  void setMaxQualityCover(bool enabled) {
    state = state.copyWith(maxQualityCover: enabled);
    saveSettings();
  }

  void setCheckForUpdates(bool enabled) {
    state = state.copyWith(checkForUpdates: enabled);
    saveSettings();
  }

  void setUpdateChannel(String channel) {
    state = state.copyWith(updateChannel: channel);
    saveSettings();
  }

  void setSearchProvider(String? provider) {
    final sanitized = sanitizeRetiredBuiltInProviderId(provider);
    if (sanitized == null || sanitized.isEmpty) {
      state = state.copyWith(clearSearchProvider: true);
    } else {
      state = state.copyWith(searchProvider: sanitized);
    }
    saveSettings();
  }

  void setDefaultSearchTab(String tab) {
    state = state.copyWith(defaultSearchTab: normalizeDefaultSearchTab(tab));
    saveSettings();
  }

  void setHomeFeedProvider(String? provider) {
    if (provider == null || provider.isEmpty) {
      state = state.copyWith(clearHomeFeedProvider: true);
    } else {
      state = state.copyWith(homeFeedProvider: provider);
    }
    saveSettings();
  }

  void setDownloadFallbackExtensionIds(List<String>? extensionIds) {
    final sanitized = sanitizeDownloadFallbackExtensionIds(extensionIds);
    state = state.copyWith(
      downloadFallbackExtensionIds: sanitized,
      clearDownloadFallbackExtensionIds:
          extensionIds == null && state.downloadFallbackExtensionIds != null,
    );
    saveSettings();
    syncExtensionFallbackSettingsToBackend();
  }

  void setSongLinkRegion(String region) {
    final normalized = normalizeSongLinkRegion(region);
    state = state.copyWith(songLinkRegion: normalized);
    saveSettings();
  }

  void setSeparateSingles(bool enabled) {
    state = state.copyWith(separateSingles: enabled);
    saveSettings();
  }

  void setAlbumFolderStructure(String mode) {
    state = state.copyWith(albumFolderStructure: mode);
    saveSettings();
  }
}