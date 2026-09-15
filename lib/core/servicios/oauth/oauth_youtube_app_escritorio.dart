// ─────────────────────────────────────────────────────────────
// oauth_youtube_app_escritorio.dart — PART de oauth_youtube_app.dart:
// piezas del OAuth in-app para escritorio — si la plataforma tiene
// WebView embebida de webview_flutter y el flujo alternativo que abre
// el consentimiento en el navegador del sistema mientras hace poll del
// listener de loopback de Go (pollYoutubeOauth).
// Se conecta con: oauth_youtube_app.dart (misma library) + backend_go.
// Parte del flujo: Ajustes → Google → Conectar YouTube.
// ─────────────────────────────────────────────────────────────

part of 'oauth_youtube_app.dart';

/// True donde hay implementación del WebView de webview_flutter: nativa en
/// Android/iOS/macOS y, en Windows, vía webview_win_floating (WebView2). En
/// Linux/web no existe y crear un WebViewController lanza "Null check
/// operator used on a null value".
bool _soportaWebView() {
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
Future<String?> _iniciarOAuthNavegador(
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
