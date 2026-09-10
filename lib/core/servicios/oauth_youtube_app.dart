// ─────────────────────────────────────────────────────────────
// oauth_youtube_app.dart — OAuth de YouTube in-app: arranca el
// listener de loopback del backend Go (startYoutubeOauth), abre el
// consentimiento de Google dentro de una WebView embebida (sin
// abrir Chrome externo), captura el código de redirect y lo cambia
// por tokens (exchangeYoutubeOauth). Guarda los tokens y empuja las
// credenciales a la extensión ytmusic-spotiflac vía
// ServicioCredencialesProveedor.
// Se conecta con: backend_go (startYoutubeOauth, stopYoutubeOauth,
// exchangeYoutubeOauth) + cache_ajustes + credenciales proveedor +
// oauth_youtube_webview.dart (página WebView).
// Parte del flujo: Ajustes → Google → Conectar YouTube.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/inyeccion.dart' as di;
import '../../config/secretos.dart';
import '../backend_go/contrato_backend.dart';
import '../cache/cache_ajustes.dart';
import 'oauth_youtube_webview.dart';
import 'servicio_credenciales_proveedor.dart';

/// OAuth de YouTube dentro de la app (WebView embebida, sin Chrome).
class OAuthYouTubeApp {
  static const _idExt = 'ytmusic-spotiflac';
  static const _alcance = 'https://www.googleapis.com/auth/youtube.readonly';

  static const _clienteIdEscritorio = oauthClienteIdEscritorio;
  static const _clienteSecretoEscritorio = oauthClienteSecretoEscritorio;

  /// True donde hay implementación del WebView de webview_flutter: nativa en
  /// Android/iOS/macOS y, en Windows, vía webview_win_floating (WebView2). En
  /// Linux/web no existe y crear un WebViewController lanza "Null check
  /// operator used on a null value".
  static bool _soportaWebView() {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
      default:
        return false;
    }
  }

  /// Flujo desktop: abre el consentimiento en el navegador del sistema y hace
  /// poll del listener loopback de Go hasta que capture el code (o cancele).
  static Future<String?> _iniciarOAuthNavegador(
    BackendService backend,
    String authUrl,
  ) async {
    final abierto = await launchUrl(
      Uri.parse(authUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!abierto) return null;

    // Timeout generoso: el usuario puede tardar en iniciar sesión en Google.
    const timeout = Duration(minutes: 3);
    final inicio = DateTime.now();
    while (DateTime.now().difference(inicio) < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final raw = await backend.rpcCall('pollYoutubeOauth', {});
      final res = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      if (res['done'] == true) {
        final code = res['code'] as String?;
        if (code != null && code.isNotEmpty) return code;
        return null; // error o cancelación (el listener ya respondió).
      }
    }
    return null;
  }

  /// Inicia el listener de loopback de Go y abre el consentimiento.
  /// Devuelve el mensaje de éxito o null si falló/canceló.
  static Future<String?> iniciarOAuth(BuildContext context) async {
    final backend = di.sl<BackendService>();

    final raw = await backend.rpcCall('startYoutubeOauth', {
      'client_id': _clienteIdEscritorio,
      'client_secret': _clienteSecretoEscritorio,
      'scope': _alcance,
    });

    final res = raw is String
        ? jsonDecode(raw) as Map<String, dynamic>
        : Map<String, dynamic>.from(raw as Map);

    if (res['ok'] != true) {
      return null;
    }

    final authUrl = res['auth_url'] as String;
    final redirectBase = res['redirect_uri'] as String;

    // En plataformas sin WebView embebida (Windows/Linux) el consentimiento
    // se abre en el navegador del sistema: Go captura el code en el listener
    // de loopback y acá se hace poll de pollYoutubeOauth hasta recibirlo.
    // (El WebView embebido de webview_flutter no existe en desktop y crashea
    //  con "Null check operator used on a null value".)
    String? code;
    if (!_soportaWebView()) {
      code = await _iniciarOAuthNavegador(backend, authUrl);
    } else {
      // Página WebView embebida con el consentimiento de Google.
      if (!context.mounted) return null;
      code = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PaginaWebViewOAuth(
            authUrl: authUrl,
            redirectBase: redirectBase,
          ),
        ),
      );
    }

    // Detiene el listener de loopback (pase lo que pase).
    try {
      await backend.rpcCall('stopYoutubeOauth', {});
    } catch (_) {}

    if (code == null || code.isEmpty) return null;

    // Cambia el código por tokens de acceso/refresh.
    final exchangeRaw = await backend.rpcCall(
      'exchangeYoutubeOauth',
      {'code': code},
    );

    final exchange = exchangeRaw is String
        ? jsonDecode(exchangeRaw) as Map<String, dynamic>
        : Map<String, dynamic>.from(exchangeRaw as Map);

    final accessToken = exchange['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) return null;

    final refreshToken = exchange['refresh_token'] as String?;

    // Guarda los tokens (preservando los client id/secret previos).
    final cache = di.sl<CacheAjustes>();
    final guardados = <String, String>{};
    for (final key in [
      'oauthClientId',
      'oauthClientSecret',
      'oauthAccessToken',
      'oauthRefreshToken',
    ]) {
      final v = (await cache.getAjuste('${_idExt}_$key') ?? '').trim();
      if (v.isNotEmpty) guardados[key] = v;
    }
    guardados.putIfAbsent('oauthClientId', () => _clienteIdEscritorio);
    guardados.putIfAbsent('oauthClientSecret', () => _clienteSecretoEscritorio);
    guardados['oauthAccessToken'] = accessToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      guardados['oauthRefreshToken'] = refreshToken;
    }
    await ServicioCredencialesProveedor(backend, cache)
        .guardarYReinicializar(_idExt, guardados);

    return 'Sesión de YouTube conectada ✓';
  }
}