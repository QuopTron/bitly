class ApiException implements Exception {
  final int code;
  final String message;
  final int statusCode;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode = 0,
  });

  @override
  String toString() => 'ApiException($code): $message (status: $statusCode)';
}
