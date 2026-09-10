// ─────────────────────────────────────────────────────────────
// oauth_youtube_nativo.dart — PART de servicio_oauth_youtube.dart:
// flujo nativo de Google Sign-In (Credential Manager en Android,
// picker nativo en iOS/macOS/web) y helpers de plataforma. Es la
// estrategia 1 (bonita, sin navegador); la WebView in-app es la 2.
// Las constantes OAuth viven aquí como top-level de la library para
// que tanto la clase como este part las compartan.
// Se conecta con: google_sign_in (plugin) + servicio_oauth_youtube.
// Parte del flujo: Ajustes → Google → Conectar YouTube.
// ─────────────────────────────────────────────────────────────

part of 'servicio_oauth_youtube.dart';

/// Alcance de solo lectura para YouTube.
const _alcanceOAuth = 'https://www.googleapis.com/auth/youtube.readonly';

/// Cliente Android (se empareja por paquete + SHA-1 en consola).
const _clienteIdOAuthAndroid = oauthClienteIdAndroid;

/// Cliente Web — se pasa como serverClientId en el flujo nativo Android.
const _clienteIdOAuthWeb = oauthClienteIdPorDefecto;
const _clienteSecretoOAuthWeb = oauthClienteSecretoPorDefecto;

bool _inicializadoNativo = false;

/// Si google_sign_in expone authenticate() nativo en esta plataforma
/// (Android, iOS, macOS, web). Windows/Linux no lo tienen.
bool _soportaNativo() {
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

/// Inicializa GoogleSignIn una sola vez. En Android el clientId se ignora
/// (la app se empareja por paquete + SHA-1) y se requiere serverClientId.
Future<void> _inicializar() async {
  if (_inicializadoNativo) return;
  await GoogleSignIn.instance.initialize(
    clientId: _clienteIdOAuthAndroid,
    serverClientId: _clienteIdOAuthWeb,
  );
  _inicializadoNativo = true;
}

Future<void> _signOutNativo() async {
  await _inicializar();
  await GoogleSignIn.instance.signOut();
}

/// Flujo nativo: authenticate() → authorizeScopes() (picker bonito,
/// sin abrir Chrome). Lanza _ExcepcionCanceladoUsuario si el usuario
/// cancela; cualquier otro error se propaga para caer a la WebView.
Future<String> _conectarNativo(ServicioOAuthYouTube servicio) async {
  await _inicializar();
  await GoogleSignIn.instance.signOut();

  final account = await GoogleSignIn.instance.authenticate();

  try {
    final auth = await account.authorizationClient.authorizeScopes([_alcanceOAuth]);
    if (auth.accessToken.isEmpty) throw Exception('token vacío');

    final guardados = await servicio._ajustesGuardados();
    guardados['oauthAccessToken'] = auth.accessToken;
    await ServicioCredencialesProveedor(servicio._backend, servicio._cache)
        .guardarYReinicializar(ServicioOAuthYouTube.idExt, guardados);

    return 'Sesión de YouTube conectada ✓ — ${account.email}';
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled ||
        e.code == GoogleSignInExceptionCode.interrupted) {
      throw _ExcepcionCanceladoUsuario();
    }
    rethrow;
  }
}

/// Señal interna: el usuario canceló el picker nativo.
class _ExcepcionCanceladoUsuario implements Exception {}