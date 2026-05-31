import 'package:meta/meta.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/core/base/base_service.dart';

/// Service Locator for managing all application services
/// Provides centralized initialization, disposal, and access to services
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  static final _log = AppLogger('ServiceLocator');

  factory ServiceLocator() => _instance;

  ServiceLocator._internal();

  final Map<Type, BaseService> _services = {};
  bool _initialized = false;
  bool _disposed = false;

  /// Register a service
  void register<T extends BaseService>(T service) {
    if (_disposed) {
      throw ServiceLocatorException('ServiceLocator has been disposed');
    }
    
    final serviceType = T;
    if (_services.containsKey(serviceType)) {
      _log.w('Service of type $serviceType is already registered');
      return;
    }
    
    _services[serviceType] = service;
    _log.i('Registered service: ${serviceType.toString()}');
  }

  /// Get a service by type
  T get<T extends BaseService>() {
    if (_disposed) {
      throw ServiceLocatorException('ServiceLocator has been disposed');
    }
    
    final service = _services[T];
    if (service == null) {
      throw ServiceLocatorException('Service of type $T not found');
    }
    
    return service as T;
  }

  /// Check if a service is registered
  bool has<T extends BaseService>() {
    return _services.containsKey(T);
  }

  /// Initialize all registered services
  Future<void> initializeAll() async {
    if (_initialized) {
      _log.d('Services already initialized');
      return;
    }
    
    if (_disposed) {
      throw ServiceLocatorException('ServiceLocator has been disposed');
    }
    
    _log.i('Initializing all services...');
    
    final initializationFutures = _services.entries.map((entry) async {
      final serviceType = entry.key;
      final service = entry.value;
      
      try {
        await service.initialize();
        _log.d('Initialized service: ${serviceType.toString()}');
      } catch (e) {
        _log.e('Failed to initialize service ${serviceType.toString()}: $e', e);
        rethrow;
      }
    });
    
    await Future.wait(initializationFutures);
    _initialized = true;
    _log.i('All services initialized successfully');
  }

  /// Dispose all registered services
  Future<void> disposeAll() async {
    if (_disposed) {
      _log.d('Services already disposed');
      return;
    }
    
    _log.i('Disposing all services...');
    
    final disposalFutures = _services.entries.map((entry) async {
      final serviceType = entry.key;
      final service = entry.value;
      
      try {
        await service.dispose();
        _log.d('Disposed service: ${serviceType.toString()}');
      } catch (e) {
        _log.e('Failed to dispose service ${serviceType.toString()}: $e', e);
        // Continue with other services even if one fails to dispose
      }
    });
    
    await Future.wait(disposalFutures);
    _services.clear();
    _disposed = true;
    _log.i('All services disposed successfully');
  }

  /// Check health of all services
  Future<Map<Type, ServiceHealth>> checkAllHealth() async {
    final healthResults = <Type, ServiceHealth>{};
    
    for (final entry in _services.entries) {
      final serviceType = entry.key;
      final service = entry.value;
      
      try {
        final health = await service.checkHealth();
        healthResults[serviceType] = health;
        if (!health.isHealthy) {
          _log.w('Service ${serviceType.toString()} health check failed: ${health.message}');
        }
      } catch (e) {
        _log.e('Health check failed for ${serviceType.toString()}: $e', e);
        healthResults[serviceType] = ServiceHealth.unhealthy(e.toString());
      }
    }
    
    return healthResults;
  }

  /// Get overall system health
  Future<SystemHealth> getSystemHealth() async {
    if (_services.isEmpty) {
      return SystemHealth.unhealthy('No services registered');
    }
    
    final healthResults = await checkAllHealth();
    final unhealthyServices = healthResults.values.where((h) => !h.isHealthy).length;
    
    if (unhealthyServices == 0) {
      return SystemHealth.healthy();
    } else if (unhealthyServices < healthResults.length) {
      return SystemHealth.degraded('$unhealthyServices/${healthResults.length} services unhealthy');
    } else {
      return SystemHealth.unhealthy('All services unhealthy');
    }
  }

  /// Reset the service locator (for testing)
  @visibleForTesting
  void reset() {
    _services.clear();
    _initialized = false;
    _disposed = false;
    _log.i('ServiceLocator reset');
  }
}

/// System-wide health status
class SystemHealth {
  final bool isHealthy;
  final String message;
  final DateTime timestamp;

  SystemHealth._({
    required this.isHealthy,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SystemHealth.healthy([String? message]) => SystemHealth._(
        isHealthy: true,
        message: message ?? 'System is healthy',
      );

  factory SystemHealth.degraded(String message) => SystemHealth._(
        isHealthy: false,
        message: 'System degraded: $message',
      );

  factory SystemHealth.unhealthy(String message) => SystemHealth._(
        isHealthy: false,
        message: 'System unhealthy: $message',
      );
}

/// Exception thrown by ServiceLocator
class ServiceLocatorException implements Exception {
  final String message;

  ServiceLocatorException(this.message);

  @override
  String toString() => 'ServiceLocatorException: $message';
}