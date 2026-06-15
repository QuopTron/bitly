import 'package:get_it/get_it.dart';
import '../models/store_extension_model.dart';
import '../../../../core/api/methods/store_methods.dart' as store_rpc;

class StoreRepository {
  final store_rpc.StoreMethods _store;

  StoreRepository(this._store);

  static StoreRepository get instance =>
      GetIt.I<StoreRepository>();

  Future<List<StoreExtensionModel>> getExtensions({int page = 0, String? category}) async {
    final result = await _store.getStoreExtensions();
    return (result as List<dynamic>)
        .map((e) => StoreExtensionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<StoreExtensionModel>> search(String query) async {
    final result = await _store.searchStore(query);
    return (result as List<dynamic>)
        .map((e) => StoreExtensionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getCategories() async {
    final result = await _store.getCategories();
    return (result as List<dynamic>).cast<String>();
  }

  Future<void> downloadAndInstall(String storeId) async {
    await _store.downloadStoreExtension(storeId);
  }
}
