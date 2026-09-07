import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/secrets.dart';
import '../../injection.dart';
import '../cache/settings_cache.dart';
import '../rpc/backend_service.dart';
import 'provider_credential_service.dart';
import 'youtube_in_app_oauth.dart';

/// YouTube OAuth — native Google Sign-In with in-app WebView fallback.
///
/// Strategy 1 (pretty, no Chrome): native Google Sign-In via Credential
/// Manager on Android (and the native picker on iOS/macOS).
/// Strategy 2 (in-app): Google consent rendered inside an embedded WebView.
/// Strategy 3 (last resort): the system browser.
///
/// The access token is pushed to the ytmusic-spotiflac extension.
class YoutubeOauthService {
  static const extId = 'ytmusic-spotiflac';
  static const _scope = 'https://www.googleapis.com/auth/youtube.readonly';

  /// Android OAuth client (registered with package + SHA-1). On Android the
  /// plugin ignores `clientId` and matches the app by package/SHA-1, but the
  /// client must exist in the console so Credential Manager can resolve it.
  static const _androidClientId = androidOAuthClientId;

  /// Web OAuth client — passed as `serverClientId`, which is what the native
  /// Credential Manager flow on Android requires to mint the token.
  static const _webClientId = defaultOAuthClientId;
  static const _webClientSecret = defaultOAuthClientSecret;

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      // On Android the clientId parameter is ignored (app is matched by
      // package + SHA-1); the Android OAuth client is required in the console.
      // On iOS/macOS/web it is the app's own client id.
      clientId: _androidClientId,
      // Credential Manager on Android REQUIRES a web client as serverClientId.
      serverClientId: _webClientId,
    );
    _initialized = true;
  }

  /// Whether google_sign_in exposes a native authenticate() flow on this
  /// platform (Android, iOS, macOS, web). Windows/Linux desktop do not.
  static bool _nativeSupported() {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  SettingsCache get _cache => sl<SettingsCache>();
  BackendService get _backend => sl<BackendService>();

  Future<bool> get isConnected async {
    final token = await _cache.getSetting('${extId}_oauthAccessToken');
    return token != null && token.trim().isNotEmpty;
  }

  // ─── Connect ───────────────────────────────────────────────────────

  /// Must be called with a BuildContext for the in-app fallbacks.
  ///
  /// Order: native pretty picker → in-app WebView → system browser (only if
  /// the in-app flows are impossible on this platform). Never opens Chrome
  /// on Android when the native flow is available.
  Future<String> connect([BuildContext? context]) async {
    // Strategy 1: Native Google Sign-In (pretty account picker, no browser).
    if (_nativeSupported()) {
      try {
        return await _connectNative();
      } on _UserCanceledException {
        return 'Inicio de sesión cancelado.';
      } catch (e) {
        debugPrint('YouTube OAuth: native flow failed ($e)');
        // Fall through to the in-app WebView.
      }
    } else {
      debugPrint('YouTube OAuth: no native flow on this platform');
    }

    // Strategy 2: In-app WebView (Google consent inside the app, no Chrome).
    if (context != null && context.mounted) {
      return _connectInAppWithRetry(context);
    }

    return 'No se pudo conectar YouTube en este dispositivo.';
  }

  /// Native: `authenticate()` → `authorizeScopes()` (pretty picker, no Chrome).
  Future<String> _connectNative() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();

    final account = await GoogleSignIn.instance.authenticate();

    try {
      final auth =
          await account.authorizationClient.authorizeScopes([_scope]);
      if (auth.accessToken.isEmpty) throw Exception('empty token');

      final saved = await _savedSettings();
      saved['oauthAccessToken'] = auth.accessToken;
      await ProviderCredentialService(_backend, _cache)
          .saveAndReinitialize(extId, saved);

      return 'Sesión de YouTube conectada ✓ — ${account.email}';
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw _UserCanceledException();
      }
      rethrow;
    }
  }

  /// In-app WebView fallback with single automatic retry.
  Future<String> _connectInAppWithRetry(BuildContext context) async {
    final msg = await YoutubeInAppOAuth.startOAuth(context);
    if (msg != null && msg.contains('✓')) return msg;

    // Single retry on transient failures (network glitch, etc.)
    debugPrint('YouTube OAuth: first WebView attempt failed, retrying once...');
    if (context.mounted) {
      final retryMsg = await YoutubeInAppOAuth.startOAuth(context);
      if (retryMsg != null && retryMsg.contains('✓')) return retryMsg;
    }

    return 'Error al conectar YouTube. Verifica tu conexión e intenta de nuevo.';
  }

  // ─── Token Management ──────────────────────────────────────────────

  /// Verifies if the current token is usable. If an access token is missing
  /// but a refresh token exists, automatically refreshes and persists the
  /// new token. Returns true when a valid token is available.
  Future<bool> ensureValidToken() async {
    final token = await _cache.getSetting('${extId}_oauthAccessToken');
    if (token != null && token.trim().isNotEmpty) return true;

    // No access token — try refresh if we have a refresh token.
    final refreshToken = await _cache.getSetting('${extId}_oauthRefreshToken');
    if (refreshToken == null || refreshToken.trim().isEmpty) return false;

    final clientId = await _cache.getSetting('${extId}_oauthClientId');
    final clientSecret = await _cache.getSetting('${extId}_oauthClientSecret');
    if (clientId == null || clientId.isEmpty) return false;

    try {
      final raw = await _backend.rpcCall('refreshYoutubeOauth', {
        'client_id': clientId,
        'client_secret': clientSecret ?? '',
        'refresh_token': refreshToken,
      });

      final res = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);

      if (res['ok'] == true && res['access_token'] != null) {
        final newToken = res['access_token'] as String;
        final saved = await _savedSettings();
        saved['oauthAccessToken'] = newToken;
        await ProviderCredentialService(_backend, _cache)
            .saveAndReinitialize(extId, saved);
        debugPrint('YouTube OAuth: token refreshed successfully');
        return true;
      }
    } catch (e) {
      debugPrint('YouTube OAuth: token refresh failed: $e');
    }

    return false;
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  Future<Map<String, String>> _savedSettings() async {
    const keys = [
      'oauthClientId',
      'oauthClientSecret',
      'oauthAccessToken',
      'oauthRefreshToken',
    ];
    final out = <String, String>{};
    for (final key in keys) {
      final v = (await _cache.getSetting('${extId}_$key') ?? '').trim();
      if (v.isNotEmpty) out[key] = v;
    }
    out.putIfAbsent('oauthClientId', () => _webClientId);
    out.putIfAbsent('oauthClientSecret', () => _webClientSecret);
    return out;
  }

  Future<String> logout() async {
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    final saved = await _savedSettings();
    saved.remove('oauthAccessToken');
    saved.remove('oauthRefreshToken');
    await _cache.saveSetting('${extId}_oauthAccessToken', '');
    await _cache.saveSetting('${extId}_oauthRefreshToken', '');
    await ProviderCredentialService(_backend, _cache)
        .saveAndReinitialize(extId, saved);
    return 'Sesión de YouTube cerrada.';
  }
}

class _UserCanceledException implements Exception {}
