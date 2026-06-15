import '../client/rpc_client.dart';

class SystemMethods {
  final RpcClient client;

  SystemMethods({required this.client});

  Future<bool> ping() async {
    return client.call<bool>(
      method: 'ping',
      parser: (data) => data == true,
    );
  }

  Future<bool> exitApp() async {
    return client.call<bool>(
      method: 'exitApp',
      parser: (data) => data == true,
    );
  }
}
