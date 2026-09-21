// ─────────────────────────────────────────────────────────────
// strings_oauth.dart — Textos de la conexión con YouTube (OAuth):
// éxito, cancelación y error. Se usan desde la capa de
// servicio (sin contexto) vía L10n. Español primario, inglés.
// Se conecta con: app_localizations.dart (lo expone como `oauth`) +
// servicio_oauth_youtube / oauth_youtube_app / _nativo / _helpers.
// Parte del flujo: conexión con YouTube.
// ─────────────────────────────────────────────────────────────

class StringsOAuth {
  final String conectada;
  final String cancelada;
  final String sinDispositivo;
  final String errorConexion;

  const StringsOAuth({
    required this.conectada,
    required this.cancelada,
    required this.sinDispositivo,
    required this.errorConexion,
  });

  /// Mensaje de éxito, con el email de la cuenta si se conoce.
  String conectadoCon(String? email) =>
      (email == null || email.isEmpty) ? conectada : '$conectada — $email';

  static const es = StringsOAuth(
    conectada: 'Sesión de YouTube conectada ✓',
    cancelada: 'Inicio de sesión cancelado.',
    sinDispositivo: 'No se pudo conectar YouTube en este dispositivo.',
    errorConexion:
        'Error al conectar YouTube. Verifica tu conexión e intenta de nuevo.',
  );

  static const en = StringsOAuth(
    conectada: 'YouTube session connected ✓',
    cancelada: 'Sign-in cancelled.',
    sinDispositivo: "Couldn't connect YouTube on this device.",
    errorConexion:
        "Couldn't connect YouTube. Check your connection and try again.",
  );
}
