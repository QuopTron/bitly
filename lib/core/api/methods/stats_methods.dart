import '../client/rpc_client.dart';

class StatsMethods {
  final RpcClient client;

  StatsMethods({required this.client});

  Future<Map<String, dynamic>> getTotalStats() async {
    return client.call<Map<String, dynamic>>(
      method: 'getTotalStats',
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  Future<List<Map<String, dynamic>>> getTopTracks(int limit) async {
    return client.call<List<Map<String, dynamic>>>(
      method: 'getTopTracks',
      params: {'limit': limit},
      parser: (data) => (data as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<List<Map<String, dynamic>>> getTopArtists(int limit) async {
    return client.call<List<Map<String, dynamic>>>(
      method: 'getTopArtists',
      params: {'limit': limit},
      parser: (data) => (data as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<Map<String, dynamic>> getPremiumStatus() async {
    return client.call<Map<String, dynamic>>(
      method: 'getPremiumStatus',
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  Future<bool> validatePremiumCode(String code) async {
    return client.call<bool>(
      method: 'validatePremiumCode',
      params: {'code': code},
      parser: (data) => data == true,
    );
  }

  Future<bool> setupScrobbling(Map<String, dynamic> config) async {
    return client.call<bool>(
      method: 'setupScrobbling',
      params: {'config': config},
      parser: (data) => data == true,
    );
  }
}
