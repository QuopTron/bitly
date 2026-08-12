class StringsSplash {
  final String retry;
  final String backendNotResponding;
  final String connectionError;

  const StringsSplash({
    required this.retry,
    required this.backendNotResponding,
    required this.connectionError,
  });

  static const es = StringsSplash(
    retry: 'Reintentar',
    backendNotResponding: 'Backend no responde',
    connectionError: 'Error de conexión',
  );

  static const en = StringsSplash(
    retry: 'Retry',
    backendNotResponding: 'Backend not responding',
    connectionError: 'Connection error',
  );
}

