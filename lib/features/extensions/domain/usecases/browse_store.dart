import '../../data/repositories/store_repository.dart';
import '../entities/store_extension.dart';

class BrowseStore {
  final StoreRepository repository;

  BrowseStore(this.repository);

  Future<List<StoreExtension>> call({int page = 0, String? category}) async {
    final models = await repository.getExtensions(page: page, category: category);
    return models.map((m) => m.toEntity()).toList();
  }

  Future<List<StoreExtension>> search(String query) async {
    final models = await repository.search(query);
    return models.map((m) => m.toEntity()).toList();
  }

  Future<List<String>> getCategories() async {
    return repository.getCategories();
  }

  Future<void> downloadAndInstall(String storeId) async {
    await repository.downloadAndInstall(storeId);
  }
}
