import 'package:bitly/providers/store/store_models.dart';

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