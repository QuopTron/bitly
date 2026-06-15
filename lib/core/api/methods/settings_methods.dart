import '../client/rpc_client.dart';

class SettingsMethods {
  final RpcClient client;

  SettingsMethods({required this.client});

  Future<Map<String, dynamic>> loadAppSettings() async {
    return client.call<Map<String, dynamic>>(
      method: 'loadAppSettings',
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  Future<bool> saveAppSettings(Map<String, dynamic> settings) async {
    return client.call<bool>(
      method: 'saveAppSettings',
      params: {'settings': settings},
      parser: (data) => data == true,
    );
  }

  Future<bool> setDownloadDirectory(String path) async {
    return client.call<bool>(
      method: 'setDownloadDirectory',
      params: {'path': path},
      parser: (data) => data == true,
    );
  }

  Future<List<String>> getLogs() async {
    return client.call<List<String>>(
      method: 'getLogs',
      parser: (data) => (data as List).cast<String>(),
    );
  }

  Future<bool> clearLogs() async {
    return client.call<bool>(method: 'clearLogs', parser: (data) => data == true);
  }
}
