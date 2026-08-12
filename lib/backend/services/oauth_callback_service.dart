import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

final _log = Logger();

/// Result of an extension OAuth (PKCE) callback deep link.
///
/// On success the provider redirects to
/// `spotiflac://callback?code=...&state=...`; on denial to
/// `spotiflac://callback?error=...&state=...`. The `state` parameter echoes the
/// PKCE `state` sent in the authorize request, so callers can verify it
/// matches the value they generated (CSRF protection).
class OAuthResult {
  final String code;
  final String state;
  final String error;

  const OAuthResult({this.code = '', this.state = '', this.error = ''});

  bool get ok => code.isNotEmpty;
  bool get isError => error.isNotEmpty;

  /// True when [expected] is null (state not required) or matches our state.
  bool matchesState(String? expected) => expected == null || state == expected;
}

/// Parses an OAuth callback URL (`spotiflac://callback?...`).
///
/// Matching by host (not scheme) makes any custom-scheme callback work, like
/// `verificationGrantFromUrl`. Returns null when the URL is not a callback or
/// carries neither `code` nor `error`.
///
/// Used by the deep-link path (via tests) and available for future in-app
/// WebView flows (intercept the navigation before the browser redirects).
OAuthResult? oauthCallbackFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host != 'callback') return null;
  final result = OAuthResult(
    code: uri.queryParameters['code'] ?? '',
    state: uri.queryParameters['state'] ?? '',
    error: uri.queryParameters['error'] ?? '',
  );
  if (result.code.isEmpty && result.error.isEmpty) return null;
  return result;
}

/// Waits for an extension OAuth (PKCE) authorization callback.
///
/// The flow (e.g. the upcoming Spotify PKCE integration) opens the provider's
/// authorize page in the system browser with
/// `redirect_uri=spotiflac://callback`. On success the provider redirects
/// there with `?code=...&state=...`, Android captures the deep link and
/// forwards it over the `com.bitly/oauth_callback` MethodChannel (see
/// `MainActivity.handleOAuthCallback`), and this service completes the pending
/// waiter.
///
/// The app is already wired with the `spotiflac://callback` intent filter, so
/// only this service + the flow itself are needed once PKCE is implemented:
///
/// ```dart
/// final result = await OAuthCallbackService().waitForCallback(
///   expectedState: myState,
/// );
/// if (result == null || result.isError) return; // user denied / timeout
/// // TODO(spotify-pkce): implement exchangeOAuthCode on the backend service
/// // and call it with the authorization code to get the tokens.
/// await backend.exchangeOAuthCode('spotify-web', result.code);
/// ```
class OAuthCallbackService with WidgetsBindingObserver {
  static final OAuthCallbackService _instance = OAuthCallbackService._();
  factory OAuthCallbackService() => _instance;
  OAuthCallbackService._();

  static const _channel = MethodChannel('com.bitly/oauth_callback');
  static const _resumeGrace = Duration(seconds: 2);

  Completer<OAuthResult?>? _pending;
  Timer? _timeout;
  bool _initialized = false;

  /// Registers the native channel listener. Call once at app startup
  /// (see `app.dart`), before any `waitForCallback`. Idempotent.
  void init() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOAuthCallback') {
        _log.i('[OAuthCallbackService] OAuth callback received from deep link');
        final args = call.arguments;
        if (args is Map) {
          _complete(OAuthResult(
            code: (args['code'] as String? ?? '').trim(),
            state: (args['state'] as String? ?? '').trim(),
            error: (args['error'] as String? ?? '').trim(),
          ));
        } else {
          _complete(null);
        }
      }
      return null;
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user returned from the system browser. If the callback deep link has
    // not arrived yet, give it a short grace period; otherwise fail fast
    // instead of spinning for the full timeout.
    if (state != AppLifecycleState.resumed) return;
    final pending = _pending;
    if (pending == null) return;
    Timer(_resumeGrace, () {
      if (identical(pending, _pending)) _complete(null);
    });
  }

  /// Waits for an OAuth callback.
  ///
  /// [expectedState] (the PKCE `state`) is validated when provided; a
  /// mismatch resolves to null. Returns null on cancel, timeout, user denial
  /// or state mismatch — the caller should treat it as a failed login.
  Future<OAuthResult?> waitForCallback({
    String? expectedState,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    _complete(null); // cancel any stale pending waiter
    final completer = Completer<OAuthResult?>();
    _pending = completer;
    _timeout = Timer(timeout, () {
      _log.w('[OAuthCallbackService] OAuth callback timed out after '
          '${timeout.inMinutes} min');
      _complete(null);
    });

    final result = await completer.future;
    if (result == null) return null;
    if (result.isError) {
      _log.w('[OAuthCallbackService] OAuth error: ${result.error}');
      return null;
    }
    if (!result.matchesState(expectedState)) {
      _log.w('[OAuthCallbackService] OAuth state mismatch '
          '(expected $expectedState, got ${result.state})');
      return null;
    }
    return result;
  }

  void _complete(OAuthResult? result) {
    final c = _pending;
    _pending = null;
    _timeout?.cancel();
    _timeout = null;
    if (c != null && !c.isCompleted) c.complete(result);
  }
}
