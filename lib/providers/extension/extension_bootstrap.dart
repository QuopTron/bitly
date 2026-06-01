import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/providers/extension/extension_state.dart';
import 'package:bitly/providers/extension/extension_models.dart';

final _log = AppLogger('ExtensionProvider');

mixin ExtensionBootstrap on Notifier<ExtensionState> {
    static const List<String> _defaultExtensionIds = [
      'deezer', 'amazon', 'ytmusic-spotiflac', 'qobuz-web', 'tidal-web',
      'soundcloud', 'pandora', 'apple-music', 'spotify-web',
    ];

  @Deprecated('Use initialize() instead. Bootstrap is handled by the backend automatically.')
  Future<List<String>> ensureDefaultExtensionsInstalled() async {
    final installed = <String>[];
    try {
      await _bootstrapRefreshExtensions();
      final cacheDir = await getTemporaryDirectory();
      await PlatformBridge.initExtensionStore(cacheDir.path);
      for (final extId in _defaultExtensionIds) {
        final ext = state.extensions.where((e) => e.id == extId).firstOrNull;
        if (ext != null && ext.enabled) continue;
        try {
          if (ext == null) {
            final tempRoot = await getTemporaryDirectory();
            final installDir = await Directory('${tempRoot.path}/bootstrap_$extId').create(recursive: true);
            final downloadPath = await PlatformBridge.downloadStoreExtension(extId, installDir.path);
            final success = await _installExtension(downloadPath);
            if (!success) { _log.w('Failed to install default extension: $extId'); continue; }
            installed.add(extId);
          }
        } catch (e) { _log.w('Failed to auto-install extension $extId: $e'); }
      }
      if (installed.isNotEmpty) await _bootstrapRefreshExtensions();
    } catch (e) { _log.w('Failed to auto-install default extensions: $e'); }
    return installed;
  }

  Future<bool> ensureSpotifyWebExtensionReady({bool setAsSearchProvider = true}) async {
    const spotifyWebExtensionId = 'spotify-web';
    try {
      await _bootstrapRefreshExtensions();
      var ext = state.extensions.where((e) => e.id == spotifyWebExtensionId).firstOrNull;

      if (ext == null) {
        final cacheDir = await getTemporaryDirectory();
        await PlatformBridge.initExtensionStore(cacheDir.path);
        final tempRoot = await getTemporaryDirectory();
        final installDir = await Directory('${tempRoot.path}/Bitly_bootstrap_spotify_web').create(recursive: true);
        final downloadPath = await PlatformBridge.downloadStoreExtension(spotifyWebExtensionId, installDir.path);
        final installed = await _installExtension(downloadPath);
        if (!installed) { _log.w('Failed to install spotify-web extension from store'); return false; }
        await _bootstrapRefreshExtensions();
        ext = state.extensions.where((e) => e.id == spotifyWebExtensionId).firstOrNull;
      }

      if (ext == null) { _log.w('spotify-web extension is still not available after install'); return false; }
      if (!ext.enabled) await _setExtensionEnabled(spotifyWebExtensionId, true);
      if (setAsSearchProvider) {
        final settings = ref.read(settingsProvider);
        if (settings.searchProvider != spotifyWebExtensionId) {
          ref.read(settingsProvider.notifier).setSearchProvider(spotifyWebExtensionId);
        }
      }
      _log.i('spotify-web extension is ready');
      return true;
    } catch (e) { _log.w('Failed to ensure spotify-web extension is ready: $e'); return false; }
  }

  Future<void> _bootstrapRefreshExtensions() async {
    try {
      final list = await PlatformBridge.getInstalledExtensions();
      final extensions = list.map((e) => Extension.fromJson(e)).toList();
      state = state.copyWith(extensions: extensions);
    } catch (e) { _log.e('Failed to refresh extensions: $e'); }
  }

  Future<bool> _installExtension(String filePath) async {
    try {
      await PlatformBridge.loadExtensionFromPath(filePath);
      return true;
    } catch (e) { _log.e('Failed to install extension: $e'); return false; }
  }

  Future<void> _setExtensionEnabled(String extensionId, bool enabled) async {
    await PlatformBridge.setExtensionEnabled(extensionId, enabled);
    final extensions = state.extensions.map((e) {
      if (e.id == extensionId) return e.copyWith(enabled: enabled);
      return e;
    }).toList();
    state = state.copyWith(extensions: extensions);
  }
}