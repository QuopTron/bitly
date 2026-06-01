import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/providers/settings/settings_state.dart';
import 'package:bitly/models/settings/app_settings.dart';
import 'package:bitly/models/settings/settings_copy.dart';
import 'package:bitly/services/premium/premium_service.dart';
import 'package:bitly/utils/logger.dart';

extension SettingsUiExtension on SettingsNotifier {
  void setDefaultService(String service) {
    state = state.copyWith(
      defaultService: sanitizeRetiredBuiltInProviderId(service) ?? '',
    );
    saveSettings();
  }

  void setFirstLaunchComplete() {
    state = state.copyWith(isFirstLaunch: false);
    saveSettings();
  }

  Future<void> resetToFirstLaunch({bool hardReset = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(settingsKey);
    await prefs.remove(settingsCorruptBackupKey);
    state = const AppSettings();
    await saveSettings();
    if (hardReset) {
      await PremiumService.clearSavedPremiumState();
    }
  }

  void setHasSearchedBefore() {
    if (!state.hasSearchedBefore) {
      state = state.copyWith(hasSearchedBefore: true);
      saveSettings();
    }
  }

  void setHistoryViewMode(String mode) {
    state = state.copyWith(historyViewMode: mode);
    saveSettings();
  }

  void setHistoryFilterMode(String mode) {
    state = state.copyWith(historyFilterMode: mode);
    saveSettings();
  }

  void setEnableLogging(bool enabled) {
    state = state.copyWith(enableLogging: enabled);
    saveSettings();
    LogBuffer.loggingEnabled = enabled;
  }

  void setUseExtensionProviders(bool enabled) {
    state = state.copyWith(useExtensionProviders: true);
    saveSettings();
  }

  void setShowExtensionStore(bool enabled) {
    state = state.copyWith(showExtensionStore: enabled);
    saveSettings();
  }

  void setLocale(String locale) {
    state = state.copyWith(locale: locale);
    saveSettings();
  }

  void setUsername(String name) {
    state = state.copyWith(username: name);
    saveSettings();
  }

  void setPremium(bool premium) {
    state = state.copyWith(isPremium: premium);
    saveSettings();
  }

  void setPremiumUntil(int until) {
    state = state.copyWith(premiumUntil: until);
    saveSettings();
  }

  void setPremiumCode(String code) {
    state = state.copyWith(premiumCode: code);
    saveSettings();
  }

  void setTutorialComplete() {
    state = state.copyWith(hasCompletedTutorial: true);
    saveSettings();
  }
}
