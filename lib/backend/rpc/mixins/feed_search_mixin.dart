import 'dart:convert';

import '../../../frontend/shared/models/feed_models.dart';
import '../backend_helpers.dart';
import '../backend_service.dart';

/// Home feed + search (Go RPC).
mixin FeedSearchMixin on BackendService {
  @override
  Future<List<FeedSection>> getHomeFeed({String locale = 'en'}) async {
    try { return BackendHelpers.parseFeedSections(await rpcCall('getHomeFeed', {'locale': locale})); } catch (_) { return []; }
  }

  @override
  Future<List<String>> getSources() async {
    try {
      final result = await rpcCall('getSources');
      if (result is List) return result.map((e) => e.toString()).toList();
      if (result is String && result.isNotEmpty) {
        final decoded = jsonDecode(result);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) { return []; }
  }

  @override
  Future<List<FeedItem>> search({
    required String query, String source = '',
    String type = '', int limit = 20,
  }) async {
    try {
      final params = <String, dynamic>{'query': query, 'limit': limit};
      if (source.isNotEmpty) params['source'] = source;
      if (type.isNotEmpty) params['type'] = type;
      return BackendHelpers.parseSearchResults(await rpcCall('search', params));
    } catch (_) { return []; }
  }

  @override
  Future<List<SourceSearchConfig>> getSearchConfig() async {
    try {
      final result = await rpcCall('getSearchConfig');
      final raw = result is String ? jsonDecode(result) : result;
      if (raw is List) {
        return raw
            .map((e) => SourceSearchConfig.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) { return []; }
  }

}


