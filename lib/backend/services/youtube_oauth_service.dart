import 'package:google_sign_in/google_sign_in.dart';

import '../../config/secrets.dart';
import '../../injection.dart';
import '../cache/settings_cache.dart';
import '../rpc/backend_service.dart';
import 'provider_credential_service.dart';

/// YouTube OAuth via native Google Sign-In (no browser redirect).
///
/// Uses Google Identity Services (GIS) — shows a beautiful native account
/// picker on Android instead of opening an ugly browser consent page. The
/// access token is pushed to the ytmusic-spotiflac extension, which sends
/// it as `Authorization: Bearer` on InnerTube requests, eliminating the
/// anonymous bot-gate 403s.
class YoutubeOauthService {
  static const extId = 'ytmusic-spotiflac';

  /// Read-only YouTube scope: the least invasive consent that still lets
  /// InnerTube treat the client as signed-in for playback.
  static const _scope = 'https://www.googleapis.com/auth/youtube.readonly';

  /// Built-in Google Cloud OAuth client (type: web).
  static const defaultClientId = defaultOAuthClientId;
  static const defaultClientSecret = defaultOAuthClientSecret;

  /// Lazy-initialized GoogleSignIn singleton.
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    GoogleSignIn.instance.initialize(clientId: defaultClientId);
    _initialized = true;
  }

  SettingsCache get _cache => sl<SettingsCache>();
  BackendService get _backend => sl<BackendService>();

  /// Returns true if a YouTube OAuth token is currently stored.
  Future<bool> get isConnected async {
    final token = await _cache.getSetting('${extId}_oauthAccessToken');
    return token != null && token.trim().isNotEmpty;
  }

  /// Native Google Sign-In — shows beautiful account picker, no browser.
  Future<String> connect() async {
    try {
      await _ensureInitialized();

      // Sign out first to force account picker.
      await GoogleSignIn.instance.signOut();

      // authenticate() shows the native account picker on Android.
      final account = await GoogleSignIn.instance.authenticate();

      // Request the YouTube read-only scope — this shows a consent dialog
      // if the scope hasn't been authorized yet.
      final authorization = await account.authorizationClient
          .authorizeScopes([_scope]);

      final accessToken = authorization.accessToken;
      if (accessToken.isEmpty) {
        return 'No se obtuvo el token de acceso de Google.';
      }

      // Save to extension settings so ytmusic-spotiflac uses it.
      final saved = await _savedSettings();
      final settings = {...saved, 'oauthAccessToken': accessToken};
      await ProviderCredentialService(_backend, _cache)
          .saveAndReinitialize(extId, settings);

      return 'Sesión de YouTube conectada ✓ — ${account.email}';
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return 'Inicio de sesión cancelado.';
      }
      return 'Error de Google: ${e.description ?? e.code}';
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  /// Loads saved OAuth-related settings.
  Future<Map<String, String>> _savedSettings() async {
    const keys = [
      'oauthClientId',
      'oauthClientSecret',
      'oauthAccessToken',
      'oauthRefreshToken',
    ];
    final out = <String, String>{};
    for (final key in keys) {
      final value =
          (await _cache.getSetting('${extId}_$key') ?? '').trim();
      if (value.isNotEmpty) out[key] = value;
    }
    out.putIfAbsent('oauthClientId', () => defaultClientId);
    out.putIfAbsent('oauthClientSecret', () => defaultClientSecret);
    return out;
  }

  /// Removes tokens and signs out of Google.
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
