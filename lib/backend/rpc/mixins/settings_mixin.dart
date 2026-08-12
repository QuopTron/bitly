import 'dart:convert';
import '../backend_service.dart';

/// Stream cache methods still need Go backend (HTTP streaming server).
mixin SettingsMixin on BackendService {
  @override
  Future<Map<String, dynamic>> getStreamCacheStats() async {
    final raw = await rpcCall('getStreamCacheStats');
    if (raw is String && raw.isNotEmpty) {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
    }
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> clearStreamCache() async {
    final raw = await rpcCall('clearStreamCache');
    if (raw is String && raw.isNotEmpty) {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
    }
    return <String, dynamic>{'ok': false};
  }

  @override
  Future<Map<String, dynamic>> setStreamCacheMaxMb(int mb) async {
    final raw = await rpcCall('setStreamCacheMaxMb', {'mb': mb});
    if (raw is String && raw.isNotEmpty) {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
    }
    return <String, dynamic>{'ok': false};
  }
}


