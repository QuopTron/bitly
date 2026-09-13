// ─────────────────────────────────────────────────────────────
// oauth_youtube_webview.dart — Página WebView embebida para el
// consentimiento de Google OAuth: carga authUrl, detecta cuando la
// WebView navega al redirect de loopback (redirectBase) y extrae el
// código ?code=... para devolverlo al flujo de OAuthYouTubeApp.
// Usa un User-Agent de Chrome móvil para que Google no bloquee la
// WebView embebida y el sign-in ocurra dentro de la app.
// Se conecta con: oauth_youtube_app.dart (flujo OAuth in-app).
// Parte del flujo: Ajustes → Google → Conectar YouTube.
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Página de consentimiento de Google dentro de una WebView embebida.
class PaginaWebViewOAuth extends StatefulWidget {
  final String authUrl;
  final String redirectBase;

  const PaginaWebViewOAuth({
    super.key,
    required this.authUrl,
    required this.redirectBase,
  });

  @override
  State<PaginaWebViewOAuth> createState() => _PaginaWebViewOAuthState();
}

class _PaginaWebViewOAuthState extends State<PaginaWebViewOAuth> {
  late final WebViewController _controlador;
  bool _popped = false;

  /// UA de Chrome móvil real: Google rechaza el sign-in en WebViews
  /// detectadas por UA; este UA mantiene el flujo dentro de la app.
  static const _uaChromeMovil =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    _controlador = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _onUrlChange,
          onWebResourceError: (_) {},
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));

    // UA tipo Chrome para que el consentimiento se renderice en la WebView.
    final plataforma = _controlador.platform;
    if (plataforma is AndroidWebViewController) {
      unawaited(plataforma.setUserAgent(_uaChromeMovil));
    }
  }

  void _onUrlChange(String url) {
    // La WebView llegó al redirect de loopback ("✅ Sesión recibida").
    if (url.startsWith(widget.redirectBase) && !_popped) {
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
      body: WebViewWidget(controller: _controlador),
    );
  }
}