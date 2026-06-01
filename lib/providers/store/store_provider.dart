import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/providers/store/store_state.dart';
import 'package:bitly/providers/store/store_service.dart';
import 'package:bitly/providers/store/store_init.dart';
import 'package:bitly/providers/extension/extension_provider.dart';
import 'package:bitly/utils/logger.dart';

export 'package:bitly/providers/store/store_state.dart';
export 'package:bitly/providers/store/store_models.dart';
export 'package:bitly/providers/store/store_init.dart';

final _log = AppLogger('StoreProvider');

class StoreNotifier extends Notifier<StoreState> with StoreInitLogic {
  final _service = StoreService();

  @override
  StoreState build() => const StoreState();

  void setCategory(String? category) { if (category == null) { state = state.copyWith(clearCategory: true); } else { state = state.copyWith(selectedCategory: category); } }
  void setSearchQuery(String query) { state = state.copyWith(searchQuery: query); }
  void clearSearch() { state = state.copyWith(searchQuery: '', clearCategory: true); }
  Future<bool> installExtension(String extensionId, String tempDir, String extensionsDir) async => _installExtensionImpl(extensionId, tempDir, extensionsDir, _service, ref);
  Future<bool> updateExtension(String extensionId, String tempDir) async => _updateExtensionImpl(extensionId, tempDir, _service, ref);
  Future<int> updateAll(String tempDir) async => _updateAllImpl(tempDir, _service, ref);
  void clearError() { state = state.copyWith(clearError: true); }

  Future<bool> _installExtensionImpl(String extensionId, String tempDir, String extensionsDir, StoreService service, Ref ref) async {
    state = state.copyWith(isDownloading: true, downloadingId: extensionId, clearError: true);
    try {
      _log.i('Downloading extension: $extensionId');
      final downloadPath = await service.downloadExtension(extensionId, tempDir);
      _log.i('Installing extension from: $downloadPath');
      final extNotifier = ref.read(extensionProvider.notifier);
      if (state.extensions.any((e) => e.id == extensionId && e.isInstalled)) {
        _log.w('Extension already installed: $extensionId');
        state = state.copyWith(isDownloading: false, clearDownloadingId: true);
        return false;
      }
      final success = await extNotifier.installExtension(downloadPath);
      if (success) { _log.i('Extension installed: $extensionId'); await refresh(); }
      state = state.copyWith(isDownloading: false, clearDownloadingId: true);
      return success;
    } catch (e) {
      _log.e('Failed to install extension: $e');
      state = state.copyWith(isDownloading: false, clearDownloadingId: true, error: e.toString());
      return false;
    }
  }

  Future<bool> _updateExtensionImpl(String extensionId, String tempDir, StoreService service, Ref ref) async {
    state = state.copyWith(isDownloading: true, downloadingId: extensionId, clearError: true);
    try {
      _log.i('Downloading update for: $extensionId');
      final downloadPath = await service.downloadExtension(extensionId, tempDir);
      _log.i('Upgrading extension from: $downloadPath');
      final success = await ref.read(extensionProvider.notifier).upgradeExtension(downloadPath);
      if (success) { _log.i('Extension updated: $extensionId'); await refresh(); }
      state = state.copyWith(isDownloading: false, clearDownloadingId: true);
      return success;
    } catch (e) {
      _log.e('Failed to update extension: $e');
      state = state.copyWith(isDownloading: false, clearDownloadingId: true, error: e.toString());
      return false;
    }
  }

  Future<int> _updateAllImpl(String tempDir, StoreService service, Ref ref) async {
    final updatable = state.extensions.where((e) => e.hasUpdate).toList();
    if (updatable.isEmpty) return 0;
    int successCount = 0;
    for (final ext in updatable) {
      state = state.copyWith(isDownloading: true, downloadingId: ext.id, clearError: true);
      try {
        _log.i('Downloading update for: ${ext.id}');
        final downloadPath = await service.downloadExtension(ext.id, tempDir);
        _log.i('Upgrading extension from: $downloadPath');
        if (await ref.read(extensionProvider.notifier).upgradeExtension(downloadPath)) {
          _log.i('Extension updated: ${ext.id}'); successCount++;
        }
      } catch (e) { _log.e('Failed to update extension ${ext.id}: $e'); }
    }
    state = state.copyWith(isDownloading: false, clearDownloadingId: true);
    await refresh();
    return successCount;
  }
}

final storeProvider = NotifierProvider<StoreNotifier, StoreState>(StoreNotifier.new);
