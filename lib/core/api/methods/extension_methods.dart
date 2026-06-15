import '../client/rpc_client.dart';

class ExtensionMethods {
  final RpcClient client;

  ExtensionMethods({required this.client});

  Future<List<Map<String, dynamic>>> getInstalled() async {
    return client.call<List<Map<String, dynamic>>>(
      method: 'getInstalled',
      parser: (data) => (data as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<bool> setEnabled(String id, bool enabled) async {
    return client.call<bool>(
      method: 'setEnabled',
      params: {'id': id, 'enabled': enabled},
      parser: (data) => data == true,
    );
  }

  Future<bool> install(String sourceUrl) async {
    return client.call<bool>(
      method: 'install',
      params: {'sourceUrl': sourceUrl},
      parser: (data) => data == true,
    );
  }

  Future<bool> remove(String id) async {
    return client.call<bool>(
      method: 'remove',
      params: {'id': id},
      parser: (data) => data == true,
    );
  }

  Future<int> getPriority(String id) async {
    return client.call<int>(
      method: 'getPriority',
      params: {'id': id},
      parser: (data) => (data as num).toInt(),
    );
  }

  Future<bool> setPriority(String id, int priority) async {
    return client.call<bool>(
      method: 'setPriority',
      params: {'id': id, 'priority': priority},
      parser: (data) => data == true,
    );
  }
}
