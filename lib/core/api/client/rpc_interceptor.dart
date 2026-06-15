import 'dart:async';
import 'dart:io';

mixin RpcInterceptor {
  int _attempt = 0;
  static const int maxRetries = 3;

  Future<T> withRetry<T>(Future<T> Function() call) async {
    _attempt = 0;
    while (_attempt < maxRetries) {
      try {
        return await call();
      } on SocketException {
        _attempt++;
        if (_attempt >= maxRetries) rethrow;
        await _backoff();
      } on TimeoutException {
        _attempt++;
        if (_attempt >= maxRetries) rethrow;
        await _backoff();
      } on HttpException {
        _attempt++;
        if (_attempt >= maxRetries) rethrow;
        await _backoff();
      }
    }
    throw StateError('Unreachable');
  }

  Future<void> _backoff() async {
    await Future.delayed(Duration(milliseconds: 200 * (1 << _attempt)));
  }
}
