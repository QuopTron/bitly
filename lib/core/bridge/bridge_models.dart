// Data classes used by [PlatformBridge] for cache and in-flight tracking.
library bridge_models;

class BridgeCacheEntry {
  final Map<String, dynamic> value;
  final DateTime expiresAt;

  const BridgeCacheEntry({required this.value, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class BridgeInFlight<T> {
  final String requestId;
  final String scopeKey;
  final Future<T> future;

  const BridgeInFlight({
    required this.requestId,
    required this.scopeKey,
    required this.future,
  });
}
