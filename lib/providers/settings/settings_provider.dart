library settings_provider;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bitly/models/settings/app_settings.dart';
import 'package:bitly/models/settings/settings_copy.dart';
import 'package:bitly/constants/app_info.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/services/premium/premium_service.dart';
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/providers/settings/settings_state.dart';

export 'package:bitly/providers/settings/settings_state.dart';
export 'package:bitly/providers/settings/settings_ui.dart';
export 'package:bitly/providers/settings/settings_audio.dart';
export 'package:bitly/providers/settings/settings_library.dart';
export 'package:bitly/providers/settings/settings_downloads.dart';
part 'settings_behaviour.dart';
part 'settings_sync.dart';

class SettingsNotifier extends Notifier<AppSettings> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      migrateOnAlgorithmChange: true,
    ),
  );
  bool _isSavingSettings = false;
  bool _saveQueued = false;
  String? _pendingSettingsJson;
  Timer? _premiumCheckTimer;

  @override
  AppSettings build() {
    ref.onDispose(() {
      _premiumCheckTimer?.cancel();
      _saveQueued = false;
    });

    _loadSettings().then((_) {
      settingsInitNotifier.value++;
    });
    return const AppSettings();
  }

  Future<void> _loadSettings() async {
    String? rawSettings;
    try {
      final result = await PlatformBridge.invoke('loadAppSettings');
      if (result is String && result.isNotEmpty) {
        rawSettings = result;
      }
    } catch (e) {
      settingsLog.w('Go loadAppSettings failed, fallback: $e');
    }

    if (rawSettings == null || rawSettings.isEmpty) {
      final prefs = await _prefs;
      rawSettings = prefs.getString(settingsKey);
    }

    if (rawSettings != null && rawSettings.isNotEmpty) {
      AppSettings? loaded;
      try {
        final decoded = jsonDecode(rawSettings);
        if (decoded is! Map) {
          throw const FormatException('settings root must be a JSON object');
        }
        loaded = AppSettings.fromJson(Map<String, dynamic>.from(decoded));
      } catch (e, stack) {
        settingsLog.e('Failed to load settings, resetting to defaults: $e', e, stack);
        try {
          final prefs = await _prefs;
          await prefs.setString(settingsCorruptBackupKey, rawSettings);
          await prefs.remove(settingsKey);
        } catch (backupError) {
          settingsLog.w('Failed to backup corrupt settings: $backupError');
        }
      }

      if (loaded != null) {
        final sd = sanitizeDownloadFallbackExtensionIds(
          loaded.downloadFallbackExtensionIds,
        );
        final sdt = normalizeDefaultSearchTab(loaded.defaultSearchTab);
        state = loaded.copyWith(
          useExtensionProviders: true,
          downloadFallbackExtensionIds: sd,
          clearDownloadFallbackExtensionIds:
              loaded.downloadFallbackExtensionIds != null && sd == null,
          defaultSearchTab: sdt,
          defaultService: loaded.defaultService,
          searchProvider: loaded.searchProvider,
        );

        final prefs = await _prefs;
        await _runMigrations(prefs);
        await _normalizeIosDownloadDirectoryIfNeeded();
        await _normalizeSongLinkRegionIfNeeded();
      }
    }

    final isPremium = await PremiumService.isPremium();
    if (isPremium != state.isPremium) {
      state = state.copyWith(isPremium: isPremium);
    }

    LogBuffer.loggingEnabled = state.enableLogging;

    await _cleanupRetiredSpotifySettings();
    syncLyricsSettingsToBackend();
    syncNetworkCompatibilitySettingsToBackend();
    syncExtensionFallbackSettingsToBackend();

    _startPremiumAutoValidator();
  }

  void syncLyricsSettingsToBackend() {
    if (!PlatformBridge.supportsCoreBackend) return;
    PlatformBridge.setLyricsProviders(state.lyricsProviders).catchError((Object e) { settingsLog.w('Failed to sync lyrics providers to backend: $e'); });
    PlatformBridge.setLyricsFetchOptions({'include_translation_netease': state.lyricsIncludeTranslationNetease, 'include_romanization_netease': state.lyricsIncludeRomanizationNetease, 'multi_person_word_by_word': state.lyricsMultiPersonWordByWord, 'musixmatch_language': state.musixmatchLanguage, 'apple_elrc_word_sync': state.lyricsAppleElrcWordSync,}).catchError((Object e) { settingsLog.w('Failed to sync lyrics fetch options to backend: $e'); });
  }

  void syncNetworkCompatibilitySettingsToBackend() {
    if (!PlatformBridge.supportsCoreBackend) return;
    PlatformBridge.setNetworkCompatibilityOptions(allowHttp: state.networkCompatibilityMode, insecureTls: state.networkCompatibilityMode).catchError((Object e) { settingsLog.w('Failed to sync network compatibility options to backend: $e'); });
  }

  void syncExtensionFallbackSettingsToBackend() {
    if (!PlatformBridge.supportsCoreBackend) return;
    PlatformBridge.setDownloadFallbackExtensionIds(state.downloadFallbackExtensionIds).catchError((Object e) { settingsLog.w('Failed to sync extension fallback settings to backend: $e'); });
  }

  Future<void> saveSettings() async {
    final currentJson = jsonEncode(state.toJson());
    _pendingSettingsJson = currentJson;

    try {
      await PlatformBridge.invoke('saveAppSettings', {'value': currentJson});
    } catch (e) {
      settingsLog.w('Go saveAppSettings failed: $e');
    }

    if (_isSavingSettings) {
      _saveQueued = true;
      settingsLog.d('Settings save queued');
      return;
    }

    _isSavingSettings = true;
    try {
      final prefs = await _prefs;
      do {
        final jsonToWrite = _pendingSettingsJson;
        _saveQueued = false;
        if (jsonToWrite != null) {
          await prefs.setString(settingsKey, jsonToWrite);
        }
      } while (_saveQueued);
    } catch (e) {
      settingsLog.e('Failed to save settings: $e');
    } finally {
      _isSavingSettings = false;
    }
  }

}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
