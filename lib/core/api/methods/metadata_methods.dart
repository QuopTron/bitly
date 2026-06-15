import '../client/rpc_client.dart';

class MetadataMethods {
  final RpcClient client;

  MetadataMethods({required this.client});

  Future<Map<String, dynamic>> readFileMetadata(String path) async {
    return client.call<Map<String, dynamic>>(
      method: 'readFileMetadata',
      params: {'path': path},
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> readAudioMetadata(String path) async {
    return client.call<Map<String, dynamic>>(
      method: 'readAudioMetadata',
      params: {'path': path},
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  Future<bool> editFileMetadata(String path, Map<String, dynamic> metadata) async {
    return client.call<bool>(
      method: 'editFileMetadata',
      params: {'path': path, 'metadata': metadata},
      parser: (data) => data == true,
    );
  }

  Future<String?> extractCover(String path) async {
    return client.call<String?>(
      method: 'extractCover',
      params: {'path': path},
      parser: (data) => data as String?,
    );
  }
}
