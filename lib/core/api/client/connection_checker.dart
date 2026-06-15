import 'rpc_client.dart';

class ConnectionChecker {
  final RpcClient client;

  ConnectionChecker({required this.client});

  Future<bool> ping() async {
    try {
      await client.call<bool>(
        method: 'ping',
        parser: (data) => data == true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
