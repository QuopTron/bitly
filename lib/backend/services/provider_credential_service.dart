import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../cache/settings_cache.dart';
import '../rpc/backend_service.dart';
import '../../frontend/shared/models/provider_config.dart';

/// Pushes any saved provider credentials from [SettingsCache] to the Go
/// extension system on app startup.  Call this after the extension system
/// has been initialized and extensions have been loaded.
///
/// This is separate from the settings UI widget to avoid a widget-to-backend
/// dependency; both the widget and the startup path delegate to this service.
class ProviderCredentialService {
  final BackendService _backend;
  final SettingsCache _cache;

  ProviderCredentialService(this._backend, this._cache);

  /// Push saved credentials for all known providers to the Go backend
  /// and reinitialize the relevant extensions.
  Future<void> pushCredentialsOnStartup() async {
    for (final provider in ProviderConfig.all) {
      await _pushProviderCredentials(provider);
    }
  }

  /// Saves credentials locally, pushes to the Go extension, and
  /// reinitializes it so the JS [initialize] function can store via
  /// [credentials.store].
  Future<void> saveAndReinitialize(
    String extensionId,
    Map<String, String> settings,
  ) async {
    // 1. Persist locally
    for (final e in settings.entries) {
      await _cache.saveSetting('${extensionId}_${e.key}', e.value);
    }

    // 2. Push to Go extension in-memory store
    await _backend.rpcCall('setExtensionSettings', {
      'extension_id': extensionId,
      'settings': jsonEncode(settings),
    });

    // 3. Reinitialize extension so JS initialize() stores via credentials.store
    await _backend.rpcCall('reinitializeExtension', {
      'extension_id': extensionId,
    });
  }

  /// Push saved credentials for a single provider.
  Future<void> _pushProviderCredentials(ProviderConfig provider) async {
    final settings = <String, String>{};

    for (final field in provider.fields) {
      final value =
          (await _cache.getSetting('${provider.id}_${field.key}') ?? '').trim();
      if (value.isNotEmpty) {
        settings[field.key] = value;
      }
    }
    // OAuth tokens produced by the app (no visible field) must also survive
    // restarts: push them exactly like fields so the extension re-initializes
    // with the session intact.
    for (final key in provider.extraSettingKeys) {
      final value =
          (await _cache.getSetting('${provider.id}_$key') ?? '').trim();
      if (value.isNotEmpty) {
        settings[key] = value;
      }
    }

    if (settings.isEmpty) {
      debugPrint('[ProviderCredential] No saved ${provider.displayName} credentials to push');
      return;
    }

    await _backend.rpcCall('setExtensionSettings', {
      'extension_id': provider.id,
      'settings': jsonEncode(settings),
    });

    await _backend.rpcCall('reinitializeExtension', {
      'extension_id': provider.id,
    });

    debugPrint('[ProviderCredential] Pushed saved ${provider.displayName} credentials on startup');
  }
}
