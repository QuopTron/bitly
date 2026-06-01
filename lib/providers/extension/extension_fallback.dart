import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/providers/extension/extension_state.dart';
import 'package:bitly/providers/extension/extension_manifest.dart';
import 'package:bitly/providers/settings/settings_provider.dart';

mixin ExtensionFallback on Notifier<ExtensionState> {
  String? replacedBuiltInDownloadProviderFor(String providerId) {
    final normalized = providerId.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return state.extensions
        .where((ext) => ext.enabled && ext.hasDownloadProvider && ext.replacesBuiltInProviders.contains(normalized))
        .map((ext) => ext.id).firstOrNull;
  }

  String? replacedBuiltInSearchProviderFor(String providerId) {
    final normalized = providerId.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return state.extensions
        .where((ext) => ext.enabled && ext.hasCustomSearch && ext.replacesBuiltInProviders.contains(normalized))
        .map((ext) => ext.id).firstOrNull;
  }

  String? replacedBuiltInMetadataProviderFor(String providerId) {
    final normalized = providerId.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return state.extensions
        .where((ext) => ext.enabled && ext.hasMetadataProvider && ext.replacesBuiltInProviders.contains(normalized))
        .map((ext) => ext.id).firstOrNull;
  }

  bool downloadProviderMatchesBuiltIn(String providerId, String builtInProviderId) {
    final np = providerId.trim().toLowerCase();
    final nb = builtInProviderId.trim().toLowerCase();
    if (np.isEmpty || nb.isEmpty) return false;
    if (np == nb) return true;
    return state.extensions
        .where((e) => e.enabled && e.hasDownloadProvider && e.id.toLowerCase() == np)
        .firstOrNull?.replacesBuiltInProviders.contains(nb) ?? false;
  }

  Future<void> reconcileDefaultDownloadService() async {
    final settings = ref.read(settingsProvider);
    final current = settings.defaultService.trim();
    final replacement = replacedBuiltInDownloadProviderFor(current);
    if (replacement != null) {
      ref.read(settingsProvider.notifier).setDefaultService(replacement);
      return;
    }
    final currentExt = state.extensions.where((e) => e.id == current).firstOrNull;
    if (currentExt == null || !currentExt.enabled || !currentExt.hasDownloadProvider) {
      final fallback = state.extensions
          .where((e) => e.enabled && e.hasDownloadProvider).map((e) => e.id).firstOrNull ?? '';
      ref.read(settingsProvider.notifier).setDefaultService(fallback);
    }
  }

  void reconcileSearchProvider() {
    final settings = ref.read(settingsProvider);
    final current = settings.searchProvider?.trim() ?? '';
    final replacement = replacedBuiltInSearchProviderFor(current);
    if (replacement != null) {
      ref.read(settingsProvider.notifier).setSearchProvider(replacement);
      return;
    }
    final matches = state.extensions.any((e) => e.enabled && e.hasCustomSearch && e.id == current);
    if (!matches) ref.read(settingsProvider.notifier).setSearchProvider(null);
  }
}
