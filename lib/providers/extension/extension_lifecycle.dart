import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/providers/store/store_provider.dart';
import 'package:bitly/providers/extension/extension_state.dart';
import 'package:bitly/providers/extension/extension_models.dart';
import 'package:bitly/providers/extension/extension_manifest.dart';
import 'package:bitly/providers/extension/extension_priority.dart';
import 'package:bitly/providers/extension/extension_fallback.dart';

final _log = AppLogger('ExtensionProvider');

mixin ExtensionLifecycle on Notifier<ExtensionState>, ExtensionPriority, ExtensionFallback {
  static const _extensionHealthCacheTtl = Duration(seconds: 60);
  AppLifecycleListener? _appLifecycleListener;
  bool _cleanupInFlight = false;
  Completer<void>? _initializationCompleter;
  final Map<String, DateTime> _healthExpiresAt = {};
  final Map<String, Future<ExtensionHealthStatus?>> _healthInFlight = {};

  void setupLifecycle() {
    _appLifecycleListener ??= AppLifecycleListener(onDetach: _scheduleLifecycleCleanup);
    ref.onDispose(() {
      _appLifecycleListener?.dispose();
      _appLifecycleListener = null;
      _healthExpiresAt.clear();
      _healthInFlight.clear();
    });
  }

  void _scheduleLifecycleCleanup() {
    if (_cleanupInFlight) return;
    _cleanupInFlight = true;
    unawaited(_cleanupExtensions(reason: 'lifecycle detach'));
  }

  Future<void> _cleanupExtensions({required String reason}) async {
    if (!PlatformBridge.supportsExtensionSystem) { _cleanupInFlight = false; return; }
    try {
      await PlatformBridge.cleanupExtensions();
      _log.d('Extensions cleaned up ($reason)');
    } catch (e) { _log.w('Extension cleanup failed ($reason): $e'); }
    finally { _cleanupInFlight = false; }
  }

  Future<void> initialize(String extensionsDir, String dataDir) async {
    if (state.isInitialized) return;
    if (_initializationCompleter != null) { await _initializationCompleter!.future; return; }

    final completer = Completer<void>();
    _initializationCompleter = completer;
    state = state.copyWith(isLoading: true, error: null);

    if (!PlatformBridge.supportsExtensionSystem) {
      state = state.copyWith(isInitialized: true, isLoading: false, extensions: const [], error: null);
      _log.i('Extension system disabled on this platform');
      completer.complete(); _initializationCompleter = null; return;
    }

    try {
      await PlatformBridge.initExtensionSystem(extensionsDir, dataDir);
      if (Platform.isAndroid || Platform.isIOS) await Future.delayed(const Duration(milliseconds: 100));
      _log.i('Bootstrapping essential extensions from backend...');
      final cacheDir = await getTemporaryDirectory();
      await PlatformBridge.initExtensionStore(cacheDir.path);
      await PlatformBridge.invoke('bootstrapEssentialExtensions');
      _log.i('Backend bootstrap completed');
      await loadExtensions(extensionsDir);
      try { ref.read(storeProvider.notifier).refresh(forceRefresh: true); } catch (e) { _log.w('Could not refresh store after bootstrap: $e'); }
      await loadProviderPriority();
      await loadMetadataProviderPriority();
      state = state.copyWith(isInitialized: true, isLoading: false);
      _log.i('Extension system initialized');
    } catch (e) {
      _log.e('Failed to initialize extension system: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      if (!completer.isCompleted) completer.complete();
      if (identical(_initializationCompleter, completer)) _initializationCompleter = null;
    }
  }

  Future<void> waitForInitialization({Duration timeout = const Duration(seconds: 30)}) async {
    if (state.isInitialized || !PlatformBridge.supportsExtensionSystem) return;
    final future = _initializationCompleter?.future;
    if (future == null) return;
    try { await future.timeout(timeout); } on TimeoutException { _log.w('Timed out waiting for extension initialization after $timeout'); }
  }

  Future<void> loadExtensions(String dirPath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await PlatformBridge.loadExtensionsFromDir(dirPath);
      await refreshExtensions();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _log.e('Failed to load extensions: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refreshExtensions() async {
    try {
      final list = await PlatformBridge.getInstalledExtensions();
      final extensions = list.map((e) => Extension.fromJson(e)).toList();
      state = state.copyWith(extensions: extensions);
      await reconcileDownloadProviderPriority();
      await reconcileDefaultDownloadService();
      await reconcileMetadataProviderPriority();
      reconcileSearchProvider();
      _scheduleExtensionHealthRefresh(extensions);
      _log.d('Loaded ${extensions.length} extensions');
    } catch (e) {
      _log.e('Failed to refresh extensions: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  void _scheduleExtensionHealthRefresh(List<Extension> extensions) {
    for (final ext in extensions) {
      if (!ext.enabled || !ext.hasServiceHealth) continue;
      unawaited(checkExtensionHealth(ext.id));
    }
  }

  void refreshEnabledExtensionHealth() => _scheduleExtensionHealthRefresh(state.extensions);

  Future<ExtensionHealthStatus?> checkExtensionHealth(String extensionId, {bool force = false}) async {
    final ext = state.extensions.where((e) => e.id == extensionId).firstOrNull;
    if (ext == null || !ext.hasServiceHealth) return null;
    final expiresAt = _healthExpiresAt[extensionId];
    final cached = state.healthStatuses[extensionId];
    if (!force && cached != null && expiresAt != null && DateTime.now().isBefore(expiresAt)) return cached;
    final inFlight = _healthInFlight[extensionId];
    if (!force && inFlight != null) return inFlight;
    final future = () async {
      try {
        final result = await PlatformBridge.checkExtensionHealth(extensionId);
        final status = ExtensionHealthStatus.fromJson(result);
        final updated = Map<String, ExtensionHealthStatus>.of(state.healthStatuses)..[extensionId] = status;
        _healthExpiresAt[extensionId] = DateTime.now().add(_extensionHealthCacheTtl);
        state = state.copyWith(healthStatuses: updated);
        return status;
      } catch (e) {
        _log.w('Failed to check extension health for $extensionId: $e');
        final status = ExtensionHealthStatus(extensionId: extensionId, status: 'unknown', checkedAt: DateTime.now(), checks: const []);
        final updated = Map<String, ExtensionHealthStatus>.of(state.healthStatuses)..[extensionId] = status;
        _healthExpiresAt[extensionId] = DateTime.now().add(const Duration(seconds: 20));
        state = state.copyWith(healthStatuses: updated);
        return status;
      } finally { _healthInFlight.remove(extensionId); }
    }();
    _healthInFlight[extensionId] = future;
    return future;
  }

  Future<void> cleanup() async {
    if (_cleanupInFlight) return;
    _cleanupInFlight = true;
    await _cleanupExtensions(reason: 'manual');
  }
}