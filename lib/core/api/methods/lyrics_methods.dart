import '../client/rpc_client.dart';

class LyricsMethods {
  final RpcClient client;

  LyricsMethods({required this.client});

  Future<String?> fetchLyrics(String trackId, String title, String artist) async {
    return client.call<String?>(
      method: 'fetchLyrics',
      params: {'trackId': trackId, 'title': title, 'artist': artist},
      parser: (data) => data as String?,
    );
  }

  Future<String?> getLRC(String trackId) async {
    return client.call<String?>(
      method: 'getLRC',
      params: {'trackId': trackId},
      parser: (data) => data as String?,
    );
  }

  Future<bool> fetchAndSave(String trackId, String title, String artist) async {
    return client.call<bool>(
      method: 'fetchAndSave',
      params: {'trackId': trackId, 'title': title, 'artist': artist},
      parser: (data) => data == true,
    );
  }

  Future<String> translate(String trackId, String targetLang) async {
    return client.call<String>(
      method: 'translate',
      params: {'trackId': trackId, 'targetLang': targetLang},
      parser: (data) => data as String,
    );
  }
}
