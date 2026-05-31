import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/services/núcleo/service_locator.dart';
import 'package:bitly/services/núcleo/base_service.dart';

// Mock service for testing
class MockService extends BaseService {
  bool initialized = false;
  bool disposed = false;

  @override
  Future<void> onInitialize() async {
    initialized = true;
    print('MockService.onInitialize called, initialized=$initialized');
  }

  @override
  Future<void> onDispose() async {
    disposed = true;
  }

  @override
  Future<ServiceHealth> onCheckHealth() async {
    return ServiceHealth.healthy('Mock service healthy');
  }
}

void main() {
  group('ServiceLocator Tests', () {
    late ServiceLocator serviceLocator;
    
    setUp(() {
      serviceLocator = ServiceLocator();
      // Reset any previous state
      serviceLocator.reset();
    });

    test('Service registration and retrieval', () async {
      final mockService = MockService();
      
      // Register service
      serviceLocator.register(mockService);
      
      // Verify service can be retrieved
      final retrievedService = serviceLocator.get<MockService>();
      expect(retrievedService, isNotNull);
      expect(retrievedService, equals(mockService));
    });

    test('Service initialization', () async {
      final mockService = MockService();
      serviceLocator.register(mockService);
      
      // Initialize services
      await serviceLocator.initializeAll();
      
      // Verify service was initialized
      final service = serviceLocator.get<MockService>();
      print('Service isInitialized: ${service.isInitialized}');
      print('Service initialized flag: ${(service as MockService).initialized}');
      expect(service.isInitialized, isTrue);
      expect((service as MockService).initialized, isTrue);
    });

    test('Service disposal', () async {
      final mockService = MockService();
      serviceLocator.register(mockService);
      await serviceLocator.initializeAll();
      
      // Dispose services
      await serviceLocator.disposeAll();
      
      // Verify service was disposed
      expect(() => serviceLocator.get<MockService>(), throwsException);
    });

    test('Service health checks', () async {
      final mockService = MockService();
      serviceLocator.register(mockService);
      await serviceLocator.initializeAll();
      
      // Check individual service health
      final health = await mockService.checkHealth();
      expect(health.isHealthy, isTrue);
      
      // Check all services health
      final allHealth = await serviceLocator.checkAllHealth();
      expect(allHealth.length, equals(1));
      expect(allHealth[MockService]?.isHealthy, isTrue);
    });

    test('System health', () async {
      final mockService = MockService();
      serviceLocator.register(mockService);
      await serviceLocator.initializeAll();
      
      // Check system health
      final systemHealth = await serviceLocator.getSystemHealth();
      expect(systemHealth.isHealthy, isTrue);
    });

    test('Service not found', () {
      expect(() => serviceLocator.get<MockService>(), throwsException);
    });

    test('Multiple services', () async {
      final service1 = MockService();
      final service2 = MockService();
      
      serviceLocator.register(service1);
      serviceLocator.register(service2);
      
      await serviceLocator.initializeAll();
      
      expect(serviceLocator.get<MockService>(), isNotNull);
      
      final healthResults = await serviceLocator.checkAllHealth();
      // Only one service is registered due to duplicate prevention
      expect(healthResults.length, equals(1));
    });
  });

  group('BaseService Tests', () {
    test('Service lifecycle', () async {
      final service = MockService();
      
      // Test initialization
      await service.initialize();
      expect(service.isInitialized, isTrue);
      expect((service as MockService).initialized, isTrue);
      
      // Test health check
      final health = await service.checkHealth();
      expect(health.isHealthy, isTrue);
      
      // Test disposal
      await service.dispose();
      expect(service.isDisposed, isTrue);
      expect(service.disposed, isTrue);
    });

    test('Safe execution', () async {
      final service = MockService();
      await service.initialize();
      
      // Test successful execution
      final result = await service.safeExecute(() async => 'success');
      expect(result, equals('success'));
      
      // Test execution after disposal
      await service.dispose();
      expect(
        () => service.safeExecute(() async => 'should fail'),
        throwsA(isA<ServiceDisposedException>()),
      );
    });
  });
}