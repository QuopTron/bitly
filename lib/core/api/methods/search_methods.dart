import '../client/rpc_client.dart';

class SearchMethods {
  final RpcClient client;

  SearchMethods({required this.client});

  Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    return client.call<List<Map<String, dynamic>>>(
      method: 'searchTracks',
      params: {'query': query},
      parser: (data) => (data as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<Map<String, dynamic>> searchByUrl(String url) async {
    return client.call<Map<String, dynamic>>(
      method: 'searchByUrl',
      params: {'url': url},
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  Future<bool> checkAvailability(String trackId, String source) async {
    return client.call<bool>(
      method: 'checkAvailability',
      params: {'trackId': trackId, 'source': source},
      parser: (data) => data == true,
    );
  }

  Future<List<String>> getSearchProviders() async {
    return client.call<List<String>>(
      method: 'getSearchProviders',
      parser: (data) => (data as List).cast<String>(),
    );
  }
}
