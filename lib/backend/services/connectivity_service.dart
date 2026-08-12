import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight connectivity checker using connectivity_plus.
///
/// Returns true when the device has any active network (WiFi, mobile, ethernet).
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  /// Returns `true` if the device appears to have internet access.
  static Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // Assume online on error (safe default)
    }
  }
}

