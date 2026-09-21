// ─────────────────────────────────────────────────────────────
// servicio_oauth_youtube_helpers.dart — PART de
// servicio_oauth_youtube.dart: helpers del OAuth de YouTube — elegir
// si el WebView embebido va primero (Android/Windows, para que el
// consentimiento no abra Chrome), reintentar una vez ese flujo y
// recuperar los ajustes OAuth guardados completando id/secret por
// defecto.
// Se conecta con: servicio_oauth_youtube.dart (misma library) +
// oauth_youtube_app + secretos.
// Parte del flujo: ajustes (conexión de YouTube).
// ─────────────────────────────────────────────────────────────

part of 'servicio_oauth_youtube.dart';

/// True donde la estrategia WebView-in-app va PRIMERO (Android real y
/// Windows): el flujo nativo de Google pide el consentimiento de
/// youtube.readonly en un Chrome Custom Tab — abre Chrome y sale de la
/// app. El WebView embebido (webview_flutter en Android, webview_win_floating
/// en Windows) mantiene el consentimiento dentro de la app. iOS/macOS
/// conservan su picker nativo in-app (no abre Chrome).
bool _webviewPrimero() {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.windows:
      return true;
    default:
      return false;
  }
}

/// WebView in-app con un único reintento automático.
///
/// El éxito lo decide que `iniciarOAuth` devuelva un mensaje (no-null): acá no
/// se inspecciona su texto, así el copy puede cambiar sin romper la lógica.
Future<ResultadoConexionYouTube> _conectarInAppConReintento(
  ServicioOAuthYouTube servicio,
  BuildContext context,
) async {
  final msg = await OAuthYouTubeApp.iniciarOAuth(context);
  if (msg != null) return ResultadoConexionYouTube(ok: true, mensaje: msg);

  debugPrint('YouTube OAuth: primer intento WebView falló, reintentando...');
  if (context.mounted) {
    final retryMsg = await OAuthYouTubeApp.iniciarOAuth(context);
    if (retryMsg != null) {
      return ResultadoConexionYouTube(ok: true, mensaje: retryMsg);
    }
  }

  return ResultadoConexionYouTube.fallo(L10n.actual.oauth.errorConexion);
}

/// Recupera los ajustes OAuth guardados completando id/secret por defecto.
Future<Map<String, String>> _ajustesGuardados(
  ServicioOAuthYouTube servicio,
) async {
  const keys = [
    'oauthClientId',
    'oauthClientSecret',
    'oauthAccessToken',
    'oauthRefreshToken',
  ];
  final out = <String, String>{};
  for (final key in keys) {
    final v =
        (await servicio._cache.getAjuste(
                  '${ServicioOAuthYouTube.idExt}_$key',
                ) ??
                '')
            .trim();
    if (v.isNotEmpty) out[key] = v;
  }
  out.putIfAbsent('oauthClientId', () => _clienteIdOAuthWeb);
  out.putIfAbsent('oauthClientSecret', () => _clienteSecretoOAuthWeb);
  return out;
}
