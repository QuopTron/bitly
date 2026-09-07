library;

/// Stub implementation for non-Android platforms.
///
/// Always returns false so callers use the PKCE / browser/webview flow.

class PlayServicesStatus {
  final bool available;
  final bool outdated;
  final String? message;

  const PlayServicesStatus({
    required this.available,
    required this.outdated,
    this.message,
  });

  bool get canUseNativeAuth => false;
}

Future<PlayServicesStatus> checkPlayServices() async {
  return const PlayServicesStatus(
    available: false,
    outdated: false,
    message: 'Web platform',
  );
}

Future<bool> hasNativeAuthorizationApi() async => false;
