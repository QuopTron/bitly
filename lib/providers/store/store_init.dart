import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/providers/store/store_state.dart';
import 'package:bitly/providers/store/store_service.dart';
import 'package:bitly/providers/store/store_models.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('StoreProvider');
const _registryUrlPrefKey = 'store_registry_url';

mixin StoreInitLogic on Notifier<StoreState> {
  static const _defaultRegistryUrl =
      'https://raw.githubusercontent.com/QuopTron/bitly-extensions/main/registry.json';

  Future<void> initialize(String cacheDir) async {
    if (state.isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    String savedUrl = prefs.getString(_registryUrlPrefKey) ?? '';

    if (savedUrl.isEmpty) {
      savedUrl = _defaultRegistryUrl;
      await prefs.setString(_registryUrlPrefKey, savedUrl);
      _log.i('Using default registry URL: $savedUrl');
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      registryUrl: savedUrl,
    );

    try {
      final service = StoreService();
      await service.initExtensionStore(cacheDir);

      _log.i('Setting registry URL in backend: $savedUrl');
      await service.setRegistryUrl(savedUrl);

      await refresh(serviceArg: service);

      state = state.copyWith(isInitialized: true, isLoading: false, registryUrl: savedUrl);
      _log.i('Extension store initialized successfully (registryUrl: $savedUrl)');
    } catch (e) {
      _log.e('Failed to initialize store: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setRegistryUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(error: 'Please enter a valid URL');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final service = StoreService();
      await service.setRegistryUrl(trimmed);

      final resolvedUrl = await service.getRegistryUrl();

      if (!(Uri.tryParse(resolvedUrl)?.hasAbsolutePath ?? false)) {
        throw Exception('Invalid registry URL: $resolvedUrl');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_registryUrlPrefKey, resolvedUrl);

      state = state.copyWith(
        registryUrl: resolvedUrl,
        extensions: const [],
      );

      _log.i('Registry URL set to: $resolvedUrl');
      await refresh(serviceArg: service, forceRefresh: true);
    } catch (e) {
      _log.e('Failed to set registry URL: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> removeRegistryUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_registryUrlPrefKey);

      final service = StoreService();
      await service.clearRegistryUrl();

      state = state.copyWith(
        registryUrl: '',
        extensions: const [],
        clearCategory: true,
        searchQuery: '',
        clearError: true,
      );

      _log.i('Registry URL removed');
    } catch (e) {
      _log.e('Failed to remove registry URL: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refresh({StoreService? serviceArg, bool forceRefresh = false}) async {
    final service = serviceArg ?? StoreService();

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final stopwatch = Stopwatch()..start();
      final extensions = await service.getExtensions(
        forceRefresh: forceRefresh,
      );
      _log.d('Extensions loaded in ${stopwatch.elapsedMilliseconds}ms');

      final installedExtensions = await service.getInstalledExtensions();
      final installedIds = installedExtensions.map((e) => e['id'] as String).toSet();

      final extensionsWithStatus = extensions.map((e) {
        final ext = StoreExtension.fromJson(e);
        return ext.copyWith(
          isInstalled: installedIds.contains(ext.id),
        );
      }).toList();

      state = state.copyWith(
        extensions: extensionsWithStatus,
        isLoading: false,
      );
      _log.d('Loaded ${state.extensions.length} extensions from store (${installedIds.length} installed)');
    } catch (e) {
      _log.e('Failed to refresh store: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
