import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/providers/extension/extension_state.dart';
import 'package:bitly/providers/extension/extension_priority.dart';
import 'package:bitly/providers/extension/extension_fallback.dart';
import 'package:bitly/providers/extension/extension_models.dart';

final _log = AppLogger('ExtensionProvider');

mixin ExtensionManagement on Notifier<ExtensionState>, ExtensionPriority, ExtensionFallback {
  Future<bool> installExtension(String filePath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await PlatformBridge.loadExtensionFromPath(filePath);
      _log.i('Installed extension: ${result['name']}');
      await _refreshExtensions();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      _log.e('Failed to install extension: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<ExtensionInstallBatchResult> installExtensions(List<String> filePaths) async {
    final uniquePaths = <String>[];
    for (final path in filePaths) {
      final trimmed = path.trim();
      if (trimmed.isEmpty || uniquePaths.contains(trimmed)) continue;
      uniquePaths.add(trimmed);
    }
    if (uniquePaths.isEmpty) return const ExtensionInstallBatchResult(attempted: 0, installed: 0);
    state = state.copyWith(isLoading: true, error: null);
    var installed = 0;
    final failures = <String, String>{};
    for (final path in uniquePaths) {
      try {
        await PlatformBridge.loadExtensionFromPath(path);
        installed++;
      } catch (e) {
        _log.e('Failed to install extension from $path: $e');
        failures[path] = e.toString();
      }
    }
    if (installed > 0) await _refreshExtensions();
    state = state.copyWith(isLoading: false, error: failures.values.firstOrNull);
    return ExtensionInstallBatchResult(attempted: uniquePaths.length, installed: installed, failures: failures);
  }

  Future<Map<String, dynamic>> checkExtensionUpgrade(String filePath) async {
    try { return await PlatformBridge.checkExtensionUpgrade(filePath); }
    catch (e) { _log.e('Failed to check extension upgrade: $e'); return {'error': e.toString()}; }
  }

  Future<bool> upgradeExtension(String filePath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await PlatformBridge.upgradeExtension(filePath);
      _log.i('Upgraded extension: ${result['display_name']} to v${result['version']}');
      await _refreshExtensions();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      _log.e('Failed to upgrade extension: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> removeExtension(String extensionId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await PlatformBridge.removeExtension(extensionId);
      _log.i('Removed extension: $extensionId');
      await _refreshExtensions();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      _log.e('Failed to remove extension: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> setExtensionEnabled(String extensionId, bool enabled) async {
    try {
      await PlatformBridge.setExtensionEnabled(extensionId, enabled);
      _log.d('Set extension $extensionId enabled: $enabled');
      final extension = state.extensions.where((e) => e.id == extensionId).firstOrNull;
      final extensions = state.extensions.map((e) {
        if (e.id == extensionId) return e.copyWith(enabled: enabled);
        return e;
      }).toList();
      state = state.copyWith(extensions: extensions);
      await _refreshExtensions();
      if (!enabled && extension != null) {
        final settings = ref.read(settingsProvider);
        if (settings.searchProvider == extensionId) {
          ref.read(settingsProvider.notifier).setSearchProvider(null);
        }
        if (extension.hasDownloadProvider && settings.defaultService == extensionId) {
          final fallback = state.extensions
              .where((e) => e.enabled && e.hasDownloadProvider).map((e) => e.id).firstOrNull ?? '';
          ref.read(settingsProvider.notifier).setDefaultService(fallback);
        }
      }
    } catch (e) {
      _log.e('Failed to set extension enabled: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Map<String, dynamic>> getExtensionSettings(String extensionId) async {
    try { return await PlatformBridge.getExtensionSettings(extensionId); }
    catch (e) { _log.e('Failed to get extension settings: $e'); return {}; }
  }

  Future<void> setExtensionSettings(String extensionId, Map<String, dynamic> s) async {
    try { await PlatformBridge.setExtensionSettings(extensionId, s); }
    catch (e) { _log.e('Failed to set extension settings: $e'); state = state.copyWith(error: e.toString()); }
  }

  Future<void> _refreshExtensions() async {
    try {
      final list = await PlatformBridge.getInstalledExtensions();
      final extensions = list.map((e) => Extension.fromJson(e)).toList();
      state = state.copyWith(extensions: extensions);
      await reconcileDownloadProviderPriority();
      await reconcileDefaultDownloadService();
      await reconcileMetadataProviderPriority();
      reconcileSearchProvider();
    } catch (e) { _log.e('Failed to refresh extensions: $e'); }
  }
}
