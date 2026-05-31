import 'package:meta/meta.dart';
import 'package:bitly/utils/logger.dart';

/// Base interface for all services in the application
/// Provides common functionality like logging, lifecycle management, and error handling
abstract class BaseService {
  late final _log = AppLogger(runtimeType.toString());
  bool _initialized = false;
  bool _disposed = false;

  /// Initialize the service
  @mustCallSuper
  Future<void> initialize() async {
    if (_initialized) return;
    _log.i('Initializing service: ${runtimeType.toString()}');
    await onInitialize();
    _initialized = true;
    _log.d('Service initialized successfully');
  }

  /// Override this method for service-specific initialization
  Future<void> onInitialize() async {
    // Base implementation does nothing
  }

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Check if service is disposed
  bool get isDisposed => _disposed;

  /// Dispose the service
  @mustCallSuper
  Future<void> dispose() async {
    if (_disposed) return;
    _log.i('Disposing service: ${runtimeType.toString()}');
    await onDispose();
    _disposed = true;
    _log.d('Service disposed successfully');
  }

  /// Override this method for service-specific cleanup
  Future<void> onDispose() async {
    // Base implementation does nothing
  }

  /// Safe execution wrapper with error handling
  @protected
  Future<T> safeExecute<T>(
    Future<T> Function() action, {
    String? operationName,
  }) async {
    if (_disposed) {
      throw ServiceDisposedException('${runtimeType.toString()} has been disposed');
    }

    try {
      final result = await action();
      _log.d('${operationName ?? 'Operation'} completed successfully');
      return result;
    } catch (e, stackTrace) {
      _log.e('${operationName ?? 'Operation'} failed: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Check service health
  Future<ServiceHealth> checkHealth() async {
    if (_disposed) return ServiceHealth.unhealthy('Service disposed');
    if (!_initialized) return ServiceHealth.degraded('Service not initialized');
    return await onCheckHealth();
  }

  /// Override for service-specific health checks
  Future<ServiceHealth> onCheckHealth() async {
    return ServiceHealth.healthy('Service is healthy');
  }
}

/// Service health status
class ServiceHealth {
  final bool isHealthy;
  final String? message;
  final DateTime timestamp;

  ServiceHealth._({
    required this.isHealthy,
    this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ServiceHealth.healthy([String? message]) => ServiceHealth._(
        isHealthy: true,
        message: message ?? 'Service is healthy',
      );

  factory ServiceHealth.degraded(String message) => ServiceHealth._(
        isHealthy: false,
        message: 'Degraded: $message',
      );

  factory ServiceHealth.unhealthy(String message) => ServiceHealth._(
        isHealthy: false,
        message: 'Unhealthy: $message',
      );

  bool get isDegraded => !isHealthy && message?.startsWith('Degraded') == true;
  bool get isUnhealthy => !isHealthy && message?.startsWith('Unhealthy') == true;
}

/// Exception thrown when trying to use a disposed service
class ServiceDisposedException implements Exception {
  final String message;

  ServiceDisposedException(this.message);

  @override
  String toString() => 'ServiceDisposedException: $message';
}