import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/secrets.dart';
import '../../injection.dart';
import '../cache/settings_cache.dart';
import '../rpc/backend_service.dart';
import 'provider_credential_service.dart';

/// In-app YouTube OAuth — shows Google consent inside a WebView
/// (no external Chrome). The Go backend's loopback server captures the
/// redirect code and exchanges it for tokens.
class YoutubeInAppOAuth {
  static const _extId = 'ytmusic-spotiflac';
  static const _scope = 'https://www.googleapis.com/auth/youtube.readonly';

  static const _desktopClientId = desktopOAuthClientId;
  static const _desktopClientSecret = desktopOAuthClientSecret;

  /// Starts the Go backend loopback listener and returns the consent URL.
  static Future<String?> startOAuth(BuildContext context) async {
    final backend = sl<BackendService>();

    final raw = await backend.rpcCall('startYoutubeOauth', {
      'client_id': _desktopClientId,
      'client_secret': _desktopClientSecret,
      'scope': _scope,
    });

    final res = raw is String
        ? jsonDecode(raw) as Map<String, dynamic>
        : Map<String, dynamic>.from(raw as Map);

    if (res['ok'] != true) {
      return null;
    }

    final authUrl = res['auth_url'] as String;
    final redirectBase = res['redirect_uri'] as String;

    // Show in-app WebView OAuth page.
    if (!context.mounted) return null;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _OAuthWebViewPage(
          authUrl: authUrl,
          redirectBase: redirectBase,
        ),
      ),
    );

    // Stop the loopback listener.
    try {
      await backend.rpcCall('stopYoutubeOauth', {});
    } catch (_) {}

    if (code == null || code.isEmpty) return null;

    // Exchange code for tokens.
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

    // Save tokens.
    final cache = sl<SettingsCache>();
    final saved = <String, String>{};
    for (final key in [
      'oauthClientId',
      'oauthClientSecret',
      'oauthAccessToken',
      'oauthRefreshToken',
    ]) {
      final v = (await cache.getSetting('${_extId}_$key') ?? '').trim();
      if (v.isNotEmpty) saved[key] = v;
    }
    saved.putIfAbsent('oauthClientId', () => _desktopClientId);
    saved.putIfAbsent('oauthClientSecret', () => _desktopClientSecret);
    saved['oauthAccessToken'] = accessToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      saved['oauthRefreshToken'] = refreshToken;
    }
    await ProviderCredentialService(backend, cache)
        .saveAndReinitialize(_extId, saved);

    return 'Sesión de YouTube conectada ✓';
  }
}

// ═══════════════════════════════════════════════════════════════
//  In-app WebView for Google OAuth consent
// ═══════════════════════════════════════════════════════════════

class _OAuthWebViewPage extends StatefulWidget {
  final String authUrl;
  final String redirectBase;

  const _OAuthWebViewPage({
    required this.authUrl,
    required this.redirectBase,
  });

  @override
  State<_OAuthWebViewPage> createState() => _OAuthWebViewPageState();
}

class _OAuthWebViewPageState extends State<_OAuthWebViewPage> {
  late final WebViewController _controller;
  final bool _loading = true;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _onUrlChange,
          onWebResourceError: (_) {},
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  void _onUrlChange(String url) {
    // Check if the WebView navigated to the loopback redirect.
    // The Go backend server shows "✅ Sesión recibida" at this URL.
    if (url.startsWith(widget.redirectBase) && !_popped) {
      // Extract code from URL query parameters.
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty && mounted) {
        _popped = true;
        Navigator.of(context).pop(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar con Google'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (!_popped) {
              _popped = true;
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
