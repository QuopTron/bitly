import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

import '../../config/secrets.dart';
import '../../injection.dart';
import '../cache/settings_cache.dart';
import '../rpc/backend_service.dart';
import 'provider_credential_service.dart';

/// Google OAuth "Iniciar sesión con YouTube" flow.
///
/// Non-invasive: the app opens Google's own consent page in the system
/// browser (the user signs in on accounts.google.com — the app never sees the
/// password). Google redirects to a 127.0.0.1 loopback listener owned by the
/// Go backend (same trick as the streaming proxy), which captures the
/// authorization code. The code is exchanged (PKCE) for an access token +
/// refresh token that are stored only on this device and pushed to the
/// ytmusic-spotiflac extension, which sends them as `Authorization: Bearer`
/// on InnerTube requests — eliminating the anonymous bot-gate 403s.
class YoutubeOauthService {
  static const extId = 'ytmusic-spotiflac';

  /// Read-only YouTube scope: the least invasive consent that still lets
  /// InnerTube treat the client as signed-in for playback.
  static const scope = 'https://www.googleapis.com/auth/youtube.readonly';

  /// Built-in Google Cloud OAuth client (type: app de escritorio / loopback).
  /// Kept as defaults so "Conectar con YouTube" works out of the box on every
  /// install; the values are loaded from secrets.dart (gitignored) and the user
  /// can override them per device from Ajustes → Credenciales → YouTube.
  static const defaultClientId = defaultOAuthClientId;
  static const defaultClientSecret = defaultOAuthClientSecret;

  SettingsCache get _cache => sl<SettingsCache>();
  BackendService get _backend => sl<BackendService>();

  /// Loads saved OAuth-related settings (client id/secret + tokens).
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
    // Built-in client so the flow works without pasting credentials first.
    // A saved value (device override) wins over the baked-in default.
    out.putIfAbsent('oauthClientId', () => defaultClientId);
    out.putIfAbsent('oauthClientSecret', () => defaultClientSecret);
    return out;
  }

  /// Runs the full OAuth connect flow and returns a user-facing status string.
  Future<String> connect() async {
    final saved = await _savedSettings();
    final clientId = saved['oauthClientId'] ?? '';
    if (clientId.isEmpty) {
      return 'Guarda primero el OAuth Client ID (y el Secret si lo tienes) en '
          'los campos de arriba y pulsa Guardar.';
    }

    dynamic start;
    try {
      start = jsonDecode(await _backend.rpcCall('startYoutubeOauth', {
        'client_id': clientId,
        'client_secret': saved['oauthClientSecret'] ?? '',
        'scope': scope,
      }));
    } catch (e) {
      return 'No se pudo iniciar OAuth: $e';
    }
    if (start is! Map || start['ok'] != true) {
      return 'No se pudo iniciar OAuth: ${start is Map ? start['error'] : start}';
    }
    final authUrl = start['auth_url'] as String? ?? '';
    if (authUrl.isEmpty) return 'No se pudo iniciar OAuth: respuesta vacía.';

    try {
      final opened = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) return 'No se pudo abrir el navegador.';
    } catch (e) {
      return 'No se pudo abrir el navegador: $e';
    }

    // Poll the in-process callback server until Google redirects back.
    String? code;
    String? error;
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    try {
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        final poll =
            jsonDecode(await _backend.rpcCall('pollYoutubeOauth', {}));
        if (poll is Map && poll['done'] == true) {
          code = poll['code'] as String?;
          error = poll['error'] as String?;
          break;
        }
      }
    } catch (_) {}

    if (code == null || code.isEmpty) {
      await _backend.rpcCall('stopYoutubeOauth', {});
      return error != null && error.isNotEmpty
          ? 'Google rechazó el acceso: $error'
          : 'Tiempo agotado esperando la confirmación de Google. Inténtalo '
              'otra vez.';
    }

    dynamic exch;
    try {
      exch =
          jsonDecode(await _backend.rpcCall('exchangeYoutubeOauth', {'code': code}));
    } catch (e) {
      await _backend.rpcCall('stopYoutubeOauth', {});
      return 'No se pudo completar la sesión: $e';
    }
    await _backend.rpcCall('stopYoutubeOauth', {});

    final access = exch is Map ? (exch['access_token'] as String? ?? '') : '';
    final refresh = exch is Map ? (exch['refresh_token'] as String? ?? '') : '';
    if (access.isEmpty) {
      final err = exch is Map ? (exch['error'] ?? 'desconocido') : exch;
      return 'No se obtuvo el token de acceso: $err';
    }

    final settings = {...saved, 'oauthAccessToken': access};
    if (refresh.isNotEmpty) settings['oauthRefreshToken'] = refresh;
    await ProviderCredentialService(_backend, _cache)
        .saveAndReinitialize(extId, settings);
    return 'Sesión de YouTube conectada ✓ — los streams ahora se resuelven '
        'como cuenta autenticada (sin límites anónimos).';
  }

  /// Removes the account tokens locally and reinitializes the extension.
  Future<String> logout() async {
    final saved = await _savedSettings();
    saved.remove('oauthAccessToken');
    saved.remove('oauthRefreshToken');
    // Also clear the on-disk copies so a restart does not restore them.
    await _cache.saveSetting('${extId}_oauthAccessToken', '');
    await _cache.saveSetting('${extId}_oauthRefreshToken', '');
    await ProviderCredentialService(_backend, _cache)
        .saveAndReinitialize(extId, saved);
    return 'Sesión de YouTube cerrada. Se eliminaron los tokens del dispositivo.';
  }
}
