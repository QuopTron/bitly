// ─────────────────────────────────────────────────────────────
// strings_conexion_google.dart — Textos de la conexión con Google
// (Ajustes → Cuenta/Más): título y bajada conectado/desconectado, y
// el error de conexión. Español primario, inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `google`)
// y settings_sheet_google_content / _google_connect.
// Parte del flujo: Ajustes (conectar YouTube).
// ─────────────────────────────────────────────────────────────

class StringsConexionGoogle {
  final String tituloConectado;
  final String tituloConectar;
  final String descConectada;
  final String descConectar;

  /// Título del WebView embebido del consentimiento de Google.
  final String tituloWebView;

  const StringsConexionGoogle({
    required this.tituloConectado,
    required this.tituloConectar,
    required this.descConectada,
    required this.descConectar,
    required this.tituloWebView,
  });

  /// Título según el estado de la cuenta.
  String titulo({required bool conectado}) =>
      conectado ? tituloConectado : tituloConectar;

  /// Bajada corta según el estado de la cuenta.
  String descripcion({required bool conectado}) =>
      conectado ? descConectada : descConectar;

  /// Error de conexión con el detalle ya interpolado.
  String errorConexion(Object e, {required bool en}) =>
      en ? 'Connection error: $e' : 'Error al conectar: $e';

  static const es = StringsConexionGoogle(
    tituloConectado: 'Google conectado',
    tituloConectar: 'Conectar con Google',
    descConectada: 'Tu cuenta de Google está conectada',
    descConectar: 'Mejora la calidad del streaming',
    tituloWebView: 'Conectar con Google',
  );

  static const en = StringsConexionGoogle(
    tituloConectado: 'Google connected',
    tituloConectar: 'Connect with Google',
    descConectada: 'Your Google account is connected',
    descConectar: 'Improves streaming quality',
    tituloWebView: 'Connect with Google',
  );
}
