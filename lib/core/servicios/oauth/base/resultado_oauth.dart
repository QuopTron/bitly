// ─────────────────────────────────────────────────────────────
// resultado_oauth.dart — Modelo del resultado de un callback OAuth
// (PKCE): código de autorización, state de CSRF y error, más la
// verificación de que el state recibido coincide con el esperado.
// Se conecta con: servicio_callback_oauth.dart (espera el callback).
// Parte del flujo: autenticación de extensiones (PKCE, deep link).
// ─────────────────────────────────────────────────────────────

/// Resultado de un callback OAuth (PKCE) de extensión.
///
/// En éxito el proveedor redirige a `spotiflac://callback?code=...&state=...`;
/// en rechazo a `spotiflac://callback?error=...&state=...`. El `state`
/// replica el `state` PKCE enviado en la petición authorize para verificar
/// que coincide (protección CSRF).
class ResultadoOAuth {
  final String code;
  final String state;
  final String error;

  const ResultadoOAuth({this.code = '', this.state = '', this.error = ''});

  bool get ok => code.isNotEmpty;
  bool get esError => error.isNotEmpty;

  /// True cuando [esperado] es null (state no requerido) o coincide.
  bool coincideConState(String? esperado) =>
      esperado == null || state == esperado;
}
