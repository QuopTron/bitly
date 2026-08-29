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
      return await _runSearch(query, source, type, limit);
    } catch (_) {
      // The native bridge serializes RPCs on one thread; a search dispatched
      // while a heavy call (download fallback / stream resolve) is in flight
      // can exceed the RPC timeout. Retry once — by then the queue drained —
      // so a transient stall never surfaces as a fake "sin resultados".
      try {
        await Future<void>.delayed(const Duration(seconds: 2));
        return await _runSearch(query, source, type, limit);
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<FeedItem>> _runSearch(String query, String source, String type, int limit) async {
    final params = <String, dynamic>{'query': query, 'limit': limit};
    if (source.isNotEmpty) params['source'] = source;
    if (type.isNotEmpty) params['type'] = type;
    return BackendHelpers.parseSearchResults(await rpcCall('search', params));
  }

  // ── Streaming search ──────────────────────────────────────────────

  @override
  Future<int> searchStreaming({
    required String query, String source = '',
    String type = '', int limit = 20,
  }) async {
    final params = <String, dynamic>{'query': query, 'limit': limit};
    if (source.isNotEmpty) params['source'] = source;
    if (type.isNotEmpty) params['type'] = type;
    try {
      final result = await rpcCall('searchStream', params);
      final raw = result is String ? jsonDecode(result) : result;
      if (raw is Map) {
        return (raw['generation'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<SearchStreamResults> getSearchStreamResults() async {
    try {
      final result = await rpcCall('getSearchStreamResults');
      final raw = result is String ? jsonDecode(result) : result;
      if (raw is Map) {
        final items = BackendHelpers.parseSearchResults(raw['items']);
        final done = raw['done'] == true;
        final gen = (raw['generation'] as num?)?.toInt() ?? 0;
        return SearchStreamResults(items: items, done: done, generation: gen);
      }
      return const SearchStreamResults(items: [], done: true, generation: 0);
    } catch (_) {
      return const SearchStreamResults(items: [], done: true, generation: 0);
    }
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


