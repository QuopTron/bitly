import '../client/rpc_client.dart';

class PlaybackMethods {
  final RpcClient client;

  PlaybackMethods({required this.client});

  Future<bool> play(Map<String, dynamic> track) async {
    return client.call<bool>(
      method: 'play',
      params: {'track': track},
      parser: (data) => data == true,
    );
  }

  Future<bool> pause() async {
    return client.call<bool>(method: 'pause', parser: (data) => data == true);
  }

  Future<bool> resume() async {
    return client.call<bool>(method: 'resume', parser: (data) => data == true);
  }

  Future<bool> stop() async {
    return client.call<bool>(method: 'stop', parser: (data) => data == true);
  }

  Future<bool> next() async {
    return client.call<bool>(method: 'next', parser: (data) => data == true);
  }

  Future<bool> previous() async {
    return client.call<bool>(method: 'previous', parser: (data) => data == true);
  }

  Future<bool> seek(Duration position) async {
    return client.call<bool>(
      method: 'seek',
      params: {'positionMs': position.inMilliseconds},
      parser: (data) => data == true,
    );
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    return client.call<List<Map<String, dynamic>>>(
      method: 'getQueue',
      parser: (data) => (data as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<bool> setQueue(List<Map<String, dynamic>> tracks) async {
    return client.call<bool>(
      method: 'setQueue',
      params: {'tracks': tracks},
      parser: (data) => data == true,
    );
  }
}
