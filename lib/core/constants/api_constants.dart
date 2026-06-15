class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://127.0.0.1:8080/rpc';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 10);
  static const Duration cacheDuration = Duration(minutes: 5);

  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const int maxConcurrentRequests = 5;

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
