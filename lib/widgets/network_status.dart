import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('NetworkStatus');

final offlineDetectorProvider = NotifierProvider<OfflineDetectorNotifier, bool>(() {
  return OfflineDetectorNotifier();
});

class NetworkStatusIcon extends ConsumerWidget {
  const NetworkStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(offlineDetectorProvider);
    final color = isOffline ? Colors.orange : Colors.green;

    return Tooltip(
      message: isOffline ? 'Sin conexión' : 'En línea',
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Icon(
          isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
          size: 18,
          color: color,
        ),
      ),
    );
  }
}

class OfflineDetectorNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    _startPeriodicCheck();
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  void _startPeriodicCheck() {
    _checkNow();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkNow());
  }

  Future<void> forceCheck() async {
    await _checkNow();
  }

  Future<void> _checkNow() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (online && state) {
        state = false;
        _log.i('Network restored');
      } else if (!online && !state) {
        state = true;
        _log.i('Network lost');
      }
    } on SocketException {
      if (!state) {
        state = true;
        _log.i('Network lost (SocketException)');
      }
    } on TimeoutException {
      if (!state) {
        state = true;
        _log.i('Network lost (timeout)');
      }
    } catch (e) {
      if (!state) {
        state = true;
        _log.i('Network lost ($e)');
      }
    }
  }
}
