import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:bitly/utils/logger.dart';

/// Base class for all providers with common functionality
/// Provides: logging, disposal handling, safe state updates
abstract class BaseNotifier<T> extends Notifier<T> {
  late final _log = AppLogger(runtimeType.toString());
  bool _disposed = false;

  @override
  T build() {
    ref.onDispose(() {
      _disposed = true;
      if (this is CacheMixin<T>) {
        (this as CacheMixin<T>).cacheClear();
      }
    });
    return initialState;
  }

  ///Override this in subclasses to provide initial state
  T get initialState;

  /// Check if the notifier has been disposed
  bool get isDisposed => _disposed;

  /// Safely update state, checks for disposal
  @protected
  void safeSetState(void Function() setter) {
    if (!isDisposed) setter();
  }

  /// Safely execute async code with disposal check
  @protected
  Future<void> safeAsync(Future<void> Function() action) async {
    if (isDisposed) return;
    try {
      await action();
    } catch (e, stack) {
      _log.e('Async operation failed: $e', e, stack);
      rethrow;
    }
  }

  /// Helper to handle errors consistently
  @protected
  String safeErrorMessage(dynamic error) {
    if (error == null) return 'unknown_error';
    if (error is String) return error;
    if (error is Exception) return error.toString();
    return 'unknown_error';
  }
}

/// Mixin for providers that need progress tracking
mixin ProgressMixin<T> on BaseNotifier<T> {
  int _progressValue = 0;
  bool _isProcessing = false;

  int get progress => _progressValue;
  bool get isProcessing => _isProcessing;

  @protected
  void updateProgress(int value) {
    _progressValue = value.clamp(0, 100);
  }

  @protected
  void setProcessing(bool processing) {
    _isProcessing = processing;
  }

  @protected
  void resetProgress() {
    _progressValue = 0;
    _isProcessing = false;
  }
}

/// Mixin for providers that need caching
mixin CacheMixin<T> on BaseNotifier<T> {
  final Map<String, dynamic> _cache = {};
  final Duration _defaultTtl = const Duration(minutes: 5);

  @protected
  void cacheSet(String key, dynamic value, {Duration? ttl}) {
    _cache[key] = _CacheEntry(value, DateTime.now().add(ttl ?? _defaultTtl));
  }

  @protected
  dynamic cacheGet(String key) {
    final entry = _cache[key] as _CacheEntry?;
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }
    return entry.value;
  }

  @protected
  void cacheClear({String? key}) {
    if (key != null) {
      _cache.remove(key);
    } else {
      _cache.clear();
    }
  }


}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  _CacheEntry(this.value, this.expiresAt);
}
