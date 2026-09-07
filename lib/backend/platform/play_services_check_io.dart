import 'dart:io' show Platform;

import 'package:google_api_availability/google_api_availability.dart';

/// Detailed Play Services availability status.
class PlayServicesStatus {
  final bool available;
  final bool outdated;
  final String? message;

  const PlayServicesStatus({
    required this.available,
    required this.outdated,
    this.message,
  });

  /// True only when Play Services is present AND up-to-date enough for
  /// native Google Sign-In (authorizeScopes).
  bool get canUseNativeAuth => available && !outdated;
}

/// Checks Play Services with tolerance for outdated versions.
/// When Play Services is present but outdated, returns [outdated]=true
/// so the caller can skip the native auth flow and use PKCE directly.
Future<PlayServicesStatus> checkPlayServices() async {
  try {
    if (!Platform.isAndroid) {
      return const PlayServicesStatus(
        available: false,
        outdated: false,
        message: 'Not Android',
      );
    }

    final availability = await GoogleApiAvailability.instance
        .checkGooglePlayServicesAvailability();

    if (availability == GooglePlayServicesAvailability.success) {
      return const PlayServicesStatus(available: true, outdated: false);
    }

    final isServiceMissing =
        availability == GooglePlayServicesAvailability.serviceMissing;
    final isVersionUpdateRequired =
        availability == GooglePlayServicesAvailability.serviceVersionUpdateRequired;

    return PlayServicesStatus(
      available: !isServiceMissing,
      outdated: isVersionUpdateRequired,
      message: 'Play Services status: $availability',
    );
  } catch (e) {
    return PlayServicesStatus(
      available: false,
      outdated: false,
      message: 'Error checking Play Services: $e',
    );
  }
}

/// Returns true only on Android devices where Google Play Services reports
/// availability AND is up-to-date. For any non-Android platform or when
/// Play Services is outdated, returns false so callers use PKCE flow.
Future<bool> hasNativeAuthorizationApi() async {
  final status = await checkPlayServices();
  return status.canUseNativeAuth;
}
