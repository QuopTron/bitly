import 'package:flutter/foundation.dart';
import 'package:bitly/utils/logger.dart';

const settingsKey = 'app_settings';
const settingsCorruptBackupKey = 'app_settings_corrupt_backup';
const migrationVersionKey = 'settings_migration_version';
const currentMigrationVersion = 11;
const spotifyClientSecretKey = 'spotify_client_secret';
const retiredBuiltInProviderIds = {'deezer', 'qobuz', 'tidal', 'youtube'};
final settingsLog = AppLogger('SettingsProvider');
final RegExp isoRegionPattern = RegExp(r'^[A-Z]{2}$');
const Set<String> searchTabValues = {
  'all',
  'track',
  'artist',
  'album',
  'playlist',
};

final settingsInitNotifier = ValueNotifier<int>(0);

String normalizeSongLinkRegion(String region) {
  final normalized = region.trim().toUpperCase();
  if (isoRegionPattern.hasMatch(normalized)) return normalized;
  return 'US';
}

String normalizeDefaultSearchTab(String value) {
  final normalized = value.trim().toLowerCase();
  if (searchTabValues.contains(normalized)) return normalized;
  return 'all';
}

String? sanitizeRetiredBuiltInProviderId(String? providerId) {
  final normalized = providerId?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return providerId;
  return retiredBuiltInProviderIds.contains(normalized) ? null : providerId;
}

List<String>? sanitizeDownloadFallbackExtensionIds(List<String>? ids) {
  if (ids == null) return null;
  final result = <String>[];
  for (final id in ids) {
    final normalized = id.trim();
    if (normalized.isEmpty || result.contains(normalized)) continue;
    result.add(normalized);
  }
  return result;
}