import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../platform/play_services_check.dart';

import '../../config/secrets.dart';
import '../../injection.dart';
import '../cache/settings_cache.dart';
import '../rpc/backend_service.dart';
import 'provider_credential_service.dart';
import 'youtube_in_app_oauth.dart';

/// YouTube OAuth — native Google Sign-In with in-app WebView fallback.
///
/// Primary: `authenticate()` → `authorizeScopes()` (native, no browser).
/// Fallback: In-app WebView showing Google consent (never leaves the app).
///
/// The access token is pushed to the ytmusic-spotiflac extension.
class YoutubeOauthService {
  static const extId = 'ytmusic-spotiflac';
  static const _scope = 'https://www.googleapis.com/auth/youtube.readonly';
  static const _webClientId = defaultOAuthClientId;
  static const _webClientSecret = defaultOAuthClientSecret;

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: _webClientId,
      serverClientId: _webClientId,
    );
    _initialized = true;
  }

  SettingsCache get _cache => sl<SettingsCache>();
  BackendService get _backend => sl<BackendService>();

  Future<bool> get isConnected async {
    final token = await _cache.getSetting('${extId}_oauthAccessToken');
    return token != null && token.trim().isNotEmpty;
  }

  // ─── Connect ───────────────────────────────────────────────────────

  /// Must be called with a BuildContext for the in-app WebView fallback.
  Future<String> connect([BuildContext? context]) async {
    // Check Play Services status with version awareness.
    PlayServicesStatus? psStatus;
    try {
      psStatus = await checkPlayServices();
    } catch (e) {
      debugPrint('Play Services check failed: $e');
    }

    // Strategy 1: Native Google Sign-In (only if Play Services is current).
    if (psStatus != null && psStatus.canUseNativeAuth) {
      try {
        return await _connectNative();
      } on _UserCanceledException {
        return 'Inicio de sesión cancelado.';
      } catch (e) {
        final err = e.toString();
        debugPrint('YouTube OAuth: native flow failed ($err)');
        // Fall through to WebView.
      }
    } else {
      final reason = psStatus?.message ?? 'unknown';
      debugPrint('Skipping native auth (Play Services: $reason) — using PKCE');
    }

    // Strategy 2: In-app WebView PKCE flow with single retry.
    if (context != null && context.mounted) {
      return _connectInAppWithRetry(context);
    }

    return 'No se pudo conectar YouTube en este dispositivo.';
  }

  /// Native: `authenticate()` → `authorizeScopes()`.
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
