import '../client/rpc_client.dart';

class StoreMethods {
  final RpcClient client;

  StoreMethods({required this.client});

  Future<List<Map<String, dynamic>>> getStoreExtensions() async {
    return client.call<List<Map<String, dynamic>>>(
      method: 'getStoreExtensions',
      parser: (data) => (data as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<List<Map<String, dynamic>>> searchStore(String query) async {
    return client.call<List<Map<String, dynamic>>>(
      method: 'searchStore',
      params: {'query': query},
      parser: (data) => (data as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<bool> downloadStoreExtension(String extensionId) async {
    return client.call<bool>(
      method: 'downloadStoreExtension',
      params: {'extensionId': extensionId},
      parser: (data) => data == true,
    );
  }

  Future<List<String>> getCategories() async {
    return client.call<List<String>>(
      method: 'getCategories',
      parser: (data) => (data as List).cast<String>(),
    );
  }
}
