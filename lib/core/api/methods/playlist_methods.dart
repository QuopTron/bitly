import '../client/rpc_client.dart';

class PlaylistMethods {
  final RpcClient client;

  PlaylistMethods({required this.client});

  Future<String> generateM3U(List<String> trackPaths) async {
    return client.call<String>(
      method: 'generateM3U',
      params: {'trackPaths': trackPaths},
      parser: (data) => data as String,
    );
  }

  Future<String> generateM3U8(List<String> trackPaths) async {
    return client.call<String>(
      method: 'generateM3U8',
      params: {'trackPaths': trackPaths},
      parser: (data) => data as String,
    );
  }

  Future<String> generateCUE(List<Map<String, dynamic>> tracks) async {
    return client.call<String>(
      method: 'generateCUE',
      params: {'tracks': tracks},
      parser: (data) => data as String,
    );
  }

  Future<String> generateNFO(Map<String, dynamic> albumInfo) async {
    return client.call<String>(
      method: 'generateNFO',
      params: {'albumInfo': albumInfo},
      parser: (data) => data as String,
    );
  }
}
