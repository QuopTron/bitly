import '../backend_service.dart';

/// RPC methods for cover cache and data reset.
mixin InfraMixin on BackendService {
  @override
  Future<String?> getCoverPathForTrack({
    required String trackId,
    String? isrc,
    String? trackName,
    String? artistName,
    String? coverUrl,
  }) async {
    try {
      return await rpcCall('getCoverPathForTrack', {
        'track_id': trackId,
        'isrc': isrc ?? '',
        'track_name': trackName ?? '',
        'artist_name': artistName ?? '',
        'cover_url': coverUrl ?? '',
      }) as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> saveCover(String coverUrl) async {
    try {
      return await rpcCall('saveCover', {'url': coverUrl}) as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteCover(String coverUrl) async {
    try {
      await rpcCall('deleteCover', {'url': coverUrl});
    } catch (_) {}
  }

  @override
  Future<bool> resetAllData() async {
    try {
      await rpcCall('resetDatabase');
      return true;
    } catch (_) {
      return false;
    }
  }
}

