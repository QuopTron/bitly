import 'dart:convert';
import '../database/app_database.dart';
import '../database/daos/settings_dao.dart';
import '../../frontend/shared/models/download_settings.dart';
import '../../frontend/shared/models/performance_profile.dart';
import '../../frontend/shared/models/setup_data.dart';
import '../rpc/backend_helpers.dart';

/// App settings local cache — wrappers over [SettingsDao].
class SettingsCache {
  final SettingsDao _s;
  SettingsCache(AppDatabase db) : _s = SettingsDao(db);

  Future<void> saveLanguage(String locale) => _s.set('locale', locale);
  Future<void> saveThemeMode(String mode) => _s.set('theme_mode', mode);
  Future<void> saveDownloadPath(String path) => _s.set('download_path', path);
  Future<String?> getDownloadPath() => _s.get('download_path');

  Future<DownloadSettings> getDownloadSettings() async {
    final all = await _s.getAll();
    final json = all.map((k, v) => MapEntry(k, _parseVal(v)));
    return DownloadSettings.fromJson(json);
  }

  Future<void> saveDownloadSettings(DownloadSettings s) async {
    for (final e in s.toJson().entries) {
      await _s.set(e.key, e.value.toString());
    }
  }

  Future<SetupData?> loadSetupData() async {
    final all = await _s.getAll();
    if (all.isEmpty) return null;
    final parsed = all.map((k, v) => MapEntry(k, _parseVal(v)));
    return BackendHelpers.parseSetupData(jsonEncode(parsed));
  }

  Future<void> completeSetup({
    required String locale, required String mode,
    required String username, String? premiumCode,
    String? existingTrialStartedAt, String? existingTrialExpiresAt,
  }) async {
    final data = BackendHelpers.buildSetupData(
      locale: locale, mode: mode, username: username, premiumCode: premiumCode,
      existingTrialStartedAt: existingTrialStartedAt,
      existingTrialExpiresAt: existingTrialExpiresAt,
    );
    for (final e in data.entries) {
      await _s.set(e.key, e.value.toString());
    }
  }

  Future<String?> getSetting(String key) => _s.get(key);

  Future<void> saveSetting(String key, String value) => _s.set(key, value);

  static const _perfKey = 'perf_profile';

  Future<PerfLevel> getPerfLevel() async {
    final raw = await _s.get(_perfKey);
    return PerfLevelX.fromKey(raw);
  }

  Future<void> savePerfLevel(PerfLevel level) => _s.set(_perfKey, level.key);

  static const _dlPriorityKey = 'download_provider_priority';

  /// Persisted ordered list of download providers (best-first). Returns an empty
  /// list when unset, meaning the backend's built-in default order is used.
  Future<List<String>> getDownloadProviderPriority() async {
    final raw = await _s.get(_dlPriorityKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is List) return list.whereType<String>().toList();
    } catch (_) {}
    return const [];
  }

  Future<void> saveDownloadProviderPriority(List<String> order) =>
      _s.set(_dlPriorityKey, jsonEncode(order));

  static dynamic _parseVal(String v) {
    if (v == 'true') return true;
    if (v == 'false') return false;
    final n = num.tryParse(v);
    if (n != null) return n;
    return v;
  }
}


