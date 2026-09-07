// Cross-platform helper for detecting native Google Play Services authorization
// availability. Exposes `hasNativeAuthorizationApi()` which returns `true`
// only on Android devices with Play Services available. On other platforms
// it returns false so callers fall back to the PKCE/browser flow.

export 'play_services_check_io.dart'
  if (dart.library.html) 'play_services_check_stub.dart';
