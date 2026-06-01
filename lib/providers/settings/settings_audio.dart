import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/models/settings/settings_copy.dart';

extension SettingsAudioExtension on SettingsNotifier {
  void setAudioQuality(String quality) {
    state = state.copyWith(audioQuality: quality);
    saveSettings();
  }

  void setEmbedReplayGain(bool enabled) {
    state = state.copyWith(embedReplayGain: enabled);
    saveSettings();
  }

  void setDownloadVideo(bool enabled) {
    state = state.copyWith(downloadVideo: enabled);
    saveSettings();
  }

  void setTidalHighFormat(String format) {
    state = state.copyWith(tidalHighFormat: format);
    saveSettings();
  }

  void setNetworkCompatibilityMode(bool enabled) {
    state = state.copyWith(networkCompatibilityMode: enabled);
    saveSettings();
    syncNetworkCompatibilitySettingsToBackend();
  }
}