import 'package:bitly/providers/extension/extension_models.dart';

extension ExtensionManifest on Extension {
  bool get hasCustomSearch => searchBehavior?.enabled ?? false;
  bool get hasURLHandler => urlHandler?.enabled ?? false;
  bool get hasCustomMatching => trackMatching?.customMatching ?? false;
  bool get hasPostProcessing => postProcessing?.enabled ?? false;
  bool get hasServiceHealth => serviceHealth.isNotEmpty;
  bool get hasHomeFeed => capabilities['homeFeed'] == true;
  bool get hasBrowseCategories => capabilities['browseCategories'] == true;
  bool get requiresNativeContainerConversion =>
      capabilities['requiresContainerConversion'] == true ||
      capabilities['requiresNativeContainerConversion'] == true;
  List<String> get replacesBuiltInProviders {
    final value = capabilities['replacesBuiltInProviders'];
    if (value is! List) return const [];
    final normalized = <String>[];
    for (final item in value) {
      if (item is! String) continue;
      final trimmed = item.trim().toLowerCase();
      if (trimmed.isEmpty || normalized.contains(trimmed)) continue;
      normalized.add(trimmed);
    }
    return normalized;
  }

  String? get preferredDownloadOutputExtension {
    final value = capabilities['downloadOutputExtension'];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> get preservedNativeOutputExtensions {
    final value = capabilities['preserveNativeOutputExtensions'];
    if (value is! List) return const [];
    final normalized = <String>[];
    for (final item in value) {
      if (item is! String) continue;
      final trimmed = item.trim().toLowerCase();
      if (trimmed.isEmpty) continue;
      normalized.add(trimmed.startsWith('.') ? trimmed : '.$trimmed');
    }
    return normalized;
  }
}
