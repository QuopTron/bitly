import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/providers/extension/extension_state.dart';
import 'package:bitly/providers/extension/extension_management.dart';
import 'package:bitly/providers/extension/extension_lifecycle.dart';
import 'package:bitly/providers/extension/extension_bootstrap.dart';
import 'package:bitly/providers/extension/extension_priority.dart';
import 'package:bitly/providers/extension/extension_fallback.dart';
import 'package:bitly/providers/extension/extension_models.dart';
import 'package:bitly/providers/extension/extension_manifest.dart';

export 'package:bitly/providers/extension/extension_state.dart';
export 'package:bitly/providers/extension/extension_management.dart';
export 'package:bitly/providers/extension/extension_lifecycle.dart';
export 'package:bitly/providers/extension/extension_bootstrap.dart';
export 'package:bitly/providers/extension/extension_priority.dart';
export 'package:bitly/providers/extension/extension_fallback.dart';
export 'package:bitly/providers/extension/extension_config.dart';
export 'package:bitly/providers/extension/extension_models.dart';
export 'package:bitly/providers/extension/extension_manifest.dart';

String resolveEffectiveDownloadService(
  String requestedService,
  ExtensionState extensionState,
) {
  final normalizedRequested = requestedService.trim().toLowerCase();
  final enabledDownloadExtensions = extensionState.extensions
      .where((ext) => ext.enabled && ext.hasDownloadProvider)
      .toList(growable: false);
  if (normalizedRequested.isNotEmpty) {
    final matchingExtension = enabledDownloadExtensions
        .where((ext) => ext.id.trim().toLowerCase() == normalizedRequested).firstOrNull;
    if (matchingExtension != null) return matchingExtension.id;
    final replacementExtension = enabledDownloadExtensions
        .where((ext) => ext.replacesBuiltInProviders.contains(normalizedRequested)).firstOrNull;
    if (replacementExtension != null) return replacementExtension.id;
  }
  return enabledDownloadExtensions.firstOrNull?.id ?? '';
}

String resolveEffectiveMetadataProvider(
  String requestedProvider,
  ExtensionState extensionState,
) {
  final normalizedRequested = requestedProvider.trim().toLowerCase();
  final enabledMetadataExtensions = extensionState.extensions
      .where((ext) => ext.enabled && ext.hasMetadataProvider)
      .toList(growable: false);
  if (normalizedRequested.isNotEmpty) {
    final matchingExtension = enabledMetadataExtensions
        .where((ext) => ext.id.trim().toLowerCase() == normalizedRequested).firstOrNull;
    if (matchingExtension != null) return matchingExtension.id;
    final replacementExtension = enabledMetadataExtensions
        .where((ext) => ext.replacesBuiltInProviders.contains(normalizedRequested)).firstOrNull;
    if (replacementExtension != null) return replacementExtension.id;
  }
  return enabledMetadataExtensions.firstOrNull?.id ?? '';
}

bool isDeezerCompatibleDownloadService(
  String service,
  ExtensionState extensionState,
) {
  final normalizedService = service.trim().toLowerCase();
  if (normalizedService.isEmpty) return false;
  return extensionState.extensions.any(
    (ext) => ext.enabled && ext.hasDownloadProvider &&
        ext.id.trim().toLowerCase() == normalizedService &&
        ext.replacesBuiltInProviders.contains('deezer'),
  );
}

String resolveProviderDisplayName(
  String providerId, {
  Iterable<Extension> extensions = const [],
}) {
  for (final extension in extensions) {
    if (extension.id == providerId) return extension.displayName;
  }
  return providerId;
}

class ExtensionNotifier extends Notifier<ExtensionState>
    with ExtensionFallback, ExtensionPriority, ExtensionManagement, ExtensionBootstrap, ExtensionLifecycle {

  @override
  ExtensionState build() {
    setupLifecycle();
    return const ExtensionState();
  }

  void clearError() => state = state.copyWith(error: null);

  Extension? getExtension(String extensionId) {
    try { return state.extensions.firstWhere((ext) => ext.id == extensionId); } catch (e) { return null; }
  }

  List<Extension> get enabledExtensions => state.extensions.where((ext) => ext.enabled).toList();
}

final extensionProvider = NotifierProvider<ExtensionNotifier, ExtensionState>(
  ExtensionNotifier.new,
);