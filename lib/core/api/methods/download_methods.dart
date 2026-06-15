import '../client/rpc_client.dart';

class DownloadMethods {
  final RpcClient client;

  DownloadMethods({required this.client});

  Future<bool> downloadByStrategy(Map<String, dynamic> params) async {
    return client.call<bool>(
      method: 'downloadByStrategy',
      params: params,
      parser: (data) => data == true,
    );
  }

  Future<bool> cancelDownload(String id) async {
    return client.call<bool>(
      method: 'cancelDownload',
      params: {'id': id},
      parser: (data) => data == true,
    );
  }

  Future<double> getProgress(String id) async {
    return client.call<double>(
      method: 'getProgress',
      params: {'id': id},
      parser: (data) => (data as num).toDouble(),
    );
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    return client.call<List<Map<String, dynamic>>>(
      method: 'getHistory',
      parser: (data) => (data as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<Map<String, int>> getQueueCounts() async {
    return client.call<Map<String, int>>(
      method: 'getQueueCounts',
      parser: (data) => (data as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
    );
  }

  Future<bool> clearHistory() async {
    return client.call<bool>(
      method: 'clearHistory',
      parser: (data) => data == true,
    );
  }
}
