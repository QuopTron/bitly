import '../client/rpc_client.dart';

class LibraryMethods {
  final RpcClient client;

  LibraryMethods({required this.client});

  Future<Map<String, dynamic>> getLocalLibraryPage(int page, int perPage) async {
    return client.call<Map<String, dynamic>>(
      method: 'getLocalLibraryPage',
      params: {'page': page, 'perPage': perPage},
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  Future<int> getLibraryCount() async {
    return client.call<int>(
      method: 'getLibraryCount',
      parser: (data) => (data as num).toInt(),
    );
  }

  Future<bool> scanLibraryFolder(String path) async {
    return client.call<bool>(
      method: 'scanLibraryFolder',
      params: {'path': path},
      parser: (data) => data == true,
    );
  }

  Future<double> getScanProgress() async {
    return client.call<double>(
      method: 'getScanProgress',
      parser: (data) => (data as num).toDouble(),
    );
  }

  Future<bool> cancelScan() async {
    return client.call<bool>(
      method: 'cancelScan',
      parser: (data) => data == true,
    );
  }

  Future<bool> deleteEntry(String id) async {
    return client.call<bool>(
      method: 'deleteEntry',
      params: {'id': id},
      parser: (data) => data == true,
    );
  }
}
