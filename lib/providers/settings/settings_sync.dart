part of 'package:bitly/providers/settings/settings_provider.dart';

extension on SettingsNotifier {
  Future<void> _runMigrations(SharedPreferences prefs) async {
    final lastMigration = prefs.getInt(migrationVersionKey) ?? 0;
    if (lastMigration < currentMigrationVersion) {
      if (state.downloadTreeUri.isNotEmpty && state.storageMode != 'saf') state = state.copyWith(storageMode: 'saf');
      if (!state.isFirstLaunch && !state.hasCompletedTutorial) state = state.copyWith(hasCompletedTutorial: true);
      if (state.lyricsProviders.contains('spotify_api')) {
        final updatedProviders = state.lyricsProviders.where((provider) => provider != 'spotify_api').toList();
        state = state.copyWith(lyricsProviders: updatedProviders.isEmpty ? const ['lrclib', 'apple_music'] : updatedProviders);
      }
      state = state.copyWith(lastSeenVersion: AppInfo.version);
      if (!state.useExtensionProviders) state = state.copyWith(useExtensionProviders: true);
      await prefs.setInt(migrationVersionKey, currentMigrationVersion);
      await saveSettings();
    }
  }

  void _startPremiumAutoValidator() {
    _premiumCheckTimer?.cancel();
    _premiumCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (state.isPremium && state.premiumUntil > 0) {
        final stillPremium = await PremiumService.isPremium();
        if (!stillPremium) { state = state.copyWith(isPremium: false); saveSettings(); settingsLog.i('Premium trial expired and revoked automatically.'); }
      }
    });
  }
}
