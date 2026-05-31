import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/constants/app_info.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/providers/extension_provider.dart';

final _log = AppLogger('StoreProvider');
final RegExp _leadingVersionPrefix = RegExp(r'^v');
const _registryUrlPrefKey = 'store_registry_url';

int compareVersions(String v1, String v2) {
  final parts1 = v1.replaceAll(_leadingVersionPrefix, '').split('.');
  final parts2 = v2.replaceAll(_leadingVersionPrefix, '').split('.');

  final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;

  for (var i = 0; i < maxLen; i++) {
    final n1 = i < parts1.length ? (int.tryParse(parts1[i]) ?? 0) : 0;
    final n2 = i < parts2.length ? (int.tryParse(parts2[i]) ?? 0) : 0;

    if (n1 < n2) return -1;
    if (n1 > n2) return 1;
  }
  return 0;
}

class StoreCategory {
  static const String metadata = 'metadata';
  static const String download = 'download';
  static const String utility = 'utility';
  static const String lyrics = 'lyrics';
  static const String integration = 'integration';

  static const List<String> all = [
    metadata,
    download,
    utility,
    lyrics,
    integration,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case metadata:
        return 'Metadata';
      case download:
        return 'Download';
      case utility:
        return 'Utility';
      case lyrics:
        return 'Lyrics';
      case integration:
        return 'Integration';
      default:
        return category;
    }
  }
}

class StoreExtension {
  final String id;
  final String name;
  final String displayName;
  final String version;
  final String description;
  final String downloadUrl;
  final String? iconUrl;
  final String category;
  final List<String> tags;
  final int downloads;
  final String updatedAt;
  final String? minAppVersion;
  final bool isInstalled;
  final String? installedVersion;
  final bool hasUpdate;

  const StoreExtension({
    required this.id,
    required this.name,
    required this.displayName,
    required this.version,
    required this.description,
    required this.downloadUrl,
    this.iconUrl,
    required this.category,
    this.tags = const [],
    this.downloads = 0,
    required this.updatedAt,
    this.minAppVersion,
    this.isInstalled = false,
    this.installedVersion,
    this.hasUpdate = false,
  });

  factory StoreExtension.fromJson(Map<String, dynamic> json) {
    return StoreExtension(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      displayName:
          json['display_name'] as String? ?? json['name'] as String? ?? '',
      version: json['version'] as String? ?? '0.0.0',
      description: json['description'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      iconUrl: json['icon_url'] as String?,
      category: json['category'] as String? ?? 'utility',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      downloads: json['downloads'] as int? ?? 0,
      updatedAt: json['updated_at'] as String? ?? '',
      minAppVersion: json['min_app_version'] as String?,
      isInstalled: json['is_installed'] as bool? ?? false,
      installedVersion: json['installed_version'] as String?,
      hasUpdate: json['has_update'] as bool? ?? false,
    );
  }

  bool get requiresNewerApp {
    if (minAppVersion == null || minAppVersion!.isEmpty) return false;
    return compareVersions(minAppVersion!, AppInfo.version) > 0;
  }

  StoreExtension copyWith({
    String? id,
    String? name,
    String? displayName,
    String? version,
    String? description,
    String? downloadUrl,
    String? iconUrl,
    String? category,
    List<String>? tags,
    int? downloads,
    String? updatedAt,
    String? minAppVersion,
    bool? isInstalled,
    String? installedVersion,
    bool? hasUpdate,
  }) {
    return StoreExtension(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      version: version ?? this.version,
      description: description ?? this.description,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      downloads: downloads ?? this.downloads,
      updatedAt: updatedAt ?? this.updatedAt,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      isInstalled: isInstalled ?? this.isInstalled,
      installedVersion: installedVersion ?? this.installedVersion,
      hasUpdate: hasUpdate ?? this.hasUpdate,
    );
  }
}

class StoreState {
  final List<StoreExtension> extensions;
  final String? selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final bool isDownloading;
  final String? downloadingId;
  final String? error;
  final bool isInitialized;
  final String registryUrl;

  const StoreState({
    this.extensions = const [],
    this.selectedCategory,
    this.searchQuery = '',
    this.isLoading = false,
    this.isDownloading = false,
    this.downloadingId,
    this.error,
    this.isInitialized = false,
    this.registryUrl = '',
  });

  bool get hasRegistryUrl => registryUrl.isNotEmpty;

  StoreState copyWith({
    List<StoreExtension>? extensions,
    String? selectedCategory,
    bool clearCategory = false,
    String? searchQuery,
    bool? isLoading,
    bool? isDownloading,
    String? downloadingId,
    bool clearDownloadingId = false,
    String? error,
    bool clearError = false,
    bool? isInitialized,
    String? registryUrl,
  }) {
    return StoreState(
      extensions: extensions ?? this.extensions,
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingId: clearDownloadingId
          ? null
          : (downloadingId ?? this.downloadingId),
      error: clearError ? null : (error ?? this.error),
      isInitialized: isInitialized ?? this.isInitialized,
      registryUrl: registryUrl ?? this.registryUrl,
    );
  }

  List<StoreExtension> get filteredExtensions {
    var result = extensions;

    if (selectedCategory != null) {
      result = result.where((e) => e.category == selectedCategory).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result
          .where(
            (e) =>
                e.name.toLowerCase().contains(query) ||
                e.displayName.toLowerCase().contains(query) ||
                e.description.toLowerCase().contains(query) ||
                e.tags.any((t) => t.toLowerCase().contains(query)),
          )
          .toList();
    }

    return result;
  }

  int get updatesAvailableCount {
    return extensions.where((e) => e.hasUpdate).length;
  }
}

class StoreNotifier extends Notifier<StoreState> {
  @override
  StoreState build() {
    return const StoreState();
  }

  static const _defaultRegistryUrl =
      'https://raw.githubusercontent.com/spotiflacapp/SpotiFLAC-Extension/main/registry.json';

  Future<void> initialize(String cacheDir) async {
    if (state.isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    String savedUrl = prefs.getString(_registryUrlPrefKey) ?? '';
    
    // Si no hay URL guardada, usar la default
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
      await PlatformBridge.initExtensionStore(cacheDir);

      // SIEMPRE configurar el registry URL en el backend Go
      _log.i('Setting registry URL in backend: $savedUrl');
      await PlatformBridge.setStoreRegistryUrl(savedUrl);

      // Cargar extensiones
      await refresh();

      state = state.copyWith(isInitialized: true, isLoading: false, registryUrl: savedUrl);
      _log.i(
        'Extension store initialized successfully (registryUrl: $savedUrl)',
      );
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
      await PlatformBridge.setStoreRegistryUrl(trimmed);

      final resolvedUrl = await PlatformBridge.getStoreRegistryUrl();

      // Validar URL
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
      await refresh(forceRefresh: true);
    } catch (e) {
      _log.e('Failed to set registry URL: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> removeRegistryUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_registryUrlPrefKey);

      await PlatformBridge.clearStoreRegistryUrl();

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

  Future<void> refresh({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Añadir cache de 5 minutos
      final stopwatch = Stopwatch()..start();
      final extensions = await PlatformBridge.getStoreExtensions(
        forceRefresh: forceRefresh,
      );
      _log.d('Extensions loaded in ${stopwatch.elapsedMilliseconds}ms');
      
      // Get installed extensions to mark them as installed
      final installedExtensions = await PlatformBridge.getInstalledExtensions();
      final installedIds = installedExtensions.map((e) => e['id'] as String).toSet();
      
      // Mark extensions as installed if they're in the installed list
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

  void setCategory(String? category) {
    if (category == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '', clearCategory: true);
  }

  Future<bool> installExtension(
    String extensionId,
    String tempDir,
    String extensionsDir,
  ) async {
    state = state.copyWith(
      isDownloading: true,
      downloadingId: extensionId,
      clearError: true,
    );

    try {
      _log.i('Downloading extension: $extensionId');
      final downloadPath = await PlatformBridge.downloadStoreExtension(
        extensionId,
        tempDir,
      );

      _log.i('Installing extension from: $downloadPath');
      final extNotifier = ref.read(extensionProvider.notifier);
      final alreadyInstalled = state.extensions.any((e) => e.id == extensionId && e.isInstalled);
      if (alreadyInstalled) {
        _log.w('Extension already installed: $extensionId');
        state = state.copyWith(isDownloading: false, clearDownloadingId: true);
        return false;
      }

      final success = await extNotifier.installExtension(downloadPath);

      if (success) {
        _log.i('Extension installed: $extensionId');
        await refresh();
      }

      state = state.copyWith(isDownloading: false, clearDownloadingId: true);
      return success;
    } catch (e) {
      _log.e('Failed to install extension: $e');
      state = state.copyWith(
        isDownloading: false,
        clearDownloadingId: true,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> updateExtension(String extensionId, String tempDir) async {
    state = state.copyWith(
      isDownloading: true,
      downloadingId: extensionId,
      clearError: true,
    );

    try {
      _log.i('Downloading update for: $extensionId');
      final downloadPath = await PlatformBridge.downloadStoreExtension(
        extensionId,
        tempDir,
      );

      _log.i('Upgrading extension from: $downloadPath');
      final extNotifier = ref.read(extensionProvider.notifier);
      final success = await extNotifier.upgradeExtension(downloadPath);

      if (success) {
        _log.i('Extension updated: $extensionId');
        await refresh();
      }

      state = state.copyWith(isDownloading: false, clearDownloadingId: true);
      return success;
    } catch (e) {
      _log.e('Failed to update extension: $e');
      state = state.copyWith(
        isDownloading: false,
        clearDownloadingId: true,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<int> updateAll(String tempDir) async {
    final updatable = state.extensions.where((e) => e.hasUpdate).toList();
    if (updatable.isEmpty) return 0;

    int successCount = 0;
    for (final ext in updatable) {
      state = state.copyWith(
        isDownloading: true,
        downloadingId: ext.id,
        clearError: true,
      );

      try {
        _log.i('Downloading update for: ${ext.id}');
        final downloadPath = await PlatformBridge.downloadStoreExtension(
          ext.id,
          tempDir,
        );

        _log.i('Upgrading extension from: $downloadPath');
        final extNotifier = ref.read(extensionProvider.notifier);
        final success = await extNotifier.upgradeExtension(downloadPath);

        if (success) {
          _log.i('Extension updated: ${ext.id}');
          successCount++;
        }
      } catch (e) {
        _log.e('Failed to update extension ${ext.id}: $e');
      }
    }

    state = state.copyWith(isDownloading: false, clearDownloadingId: true);
    await refresh();
    return successCount;
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final storeProvider = NotifierProvider<StoreNotifier, StoreState>(
  StoreNotifier.new,
);
