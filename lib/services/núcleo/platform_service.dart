import 'package:bitly/services/núcleo/base_service.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';

/// PlatformService wraps the static PlatformBridge with service lifecycle management
/// This allows PlatformBridge to integrate with the service locator pattern
class PlatformService extends BaseService {
  static final PlatformService _instance = PlatformService._internal();

  factory PlatformService() => _instance;

  PlatformService._internal();

  /// Initialize the platform service
  /// This is called automatically by the base service initialize() method
  @override
  Future<void> onInitialize() async {
    // PlatformBridge is static and doesn't need explicit initialization
    // But we can add any platform-specific setup here
  }

  /// Dispose the platform service
  /// This is called automatically by the base service dispose() method
  @override
  Future<void> onDispose() async {
    // Clean up any platform-specific resources
  }

  /// Check platform service health
  @override
  Future<ServiceHealth> onCheckHealth() async {
    try {
      // Test a simple platform bridge call to verify it's working
      final version = await PlatformBridge.invoke('getBackendVersion');
      if (version != null) {
        return ServiceHealth.healthy('Platform bridge healthy (v$version)');
      }
      return ServiceHealth.degraded('Platform bridge responsive but no version info');
    } catch (e) {
      return ServiceHealth.degraded('Platform bridge health check failed: $e');
    }
  }

  /// Wrapper for PlatformBridge.invoke with service safety checks
  Future<dynamic> invoke(String method, [dynamic args]) async {
    return safeExecute(() => PlatformBridge.invoke(method, args),
      operationName: 'PlatformBridge.invoke($method)');
  }

  /// Wrapper for PlatformBridge.initDesktopBackend
  Future<void> initDesktopBackend() async {
    await safeExecute(() => PlatformBridge.initDesktopBackend(),
      operationName: 'PlatformBridge.initDesktopBackend');
  }

  // Add wrappers for other commonly used PlatformBridge methods
  Future<dynamic> findURLHandler(String url) async {
    return safeExecute(() => PlatformBridge.findURLHandler(url),
      operationName: 'PlatformBridge.findURLHandler');
  }

  Future<dynamic> handleURLWithExtension(String url) async {
    return safeExecute(() => PlatformBridge.handleURLWithExtension(url),
      operationName: 'PlatformBridge.handleURLWithExtension');
  }

  Future<List<dynamic>> searchTracksWithMetadataProviders(
    String query, {
    int limit = 20,
    bool includeExtensions = true,
  }) async {
    return safeExecute(
      () => PlatformBridge.searchTracksWithMetadataProviders(
        query,
        limit: limit,
        includeExtensions: includeExtensions,
      ),
      operationName: 'PlatformBridge.searchTracksWithMetadataProviders',
    );
  }

  Future<dynamic> customSearchWithExtension(
    String extensionId,
    String query, {
    Map<String, dynamic>? options,
    bool cancelPrevious = false,
  }) async {
    return safeExecute(
      () => PlatformBridge.customSearchWithExtension(
        extensionId,
        query,
        options: options,
        cancelPrevious: cancelPrevious,
      ),
      operationName: 'PlatformBridge.customSearchWithExtension',
    );
  }

  Future<dynamic> getExtensionHomeFeed(
    String extensionId, {
    bool cancelPrevious = false,
  }) async {
    return safeExecute(
      () => PlatformBridge.getExtensionHomeFeed(
        extensionId,
        cancelPrevious: cancelPrevious,
      ),
      operationName: 'PlatformBridge.getExtensionHomeFeed',
    );
  }

   Future<void> cancelExtensionHomeFeedRequests() async {
    await safeExecute(
      () async => PlatformBridge.cancelExtensionHomeFeedRequests(),
      operationName: 'PlatformBridge.cancelExtensionHomeFeedRequests',
    );
  }

  Future<dynamic> checkAvailability(String trackId, String isrc) async {
    return safeExecute(
      () => PlatformBridge.checkAvailability(trackId, isrc),
      operationName: 'PlatformBridge.checkAvailability',
    );
  }

  // Add more method wrappers as needed...
}