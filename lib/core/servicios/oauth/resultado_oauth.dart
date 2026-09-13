// ─────────────────────────────────────────────────────────────
// resultado_oauth.dart — Modelo del resultado de un callback OAuth
// (PKCE): código de autorización, state de CSRF y error. Incluye el
// parseo de URLs de callback (`spotiflac://callback?...`) y la
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

  const ResultadoOAuth({
    this.code = '',
    this.state = '',
    this.error = '',
  });

  bool get ok => code.isNotEmpty;
  bool get esError => error.isNotEmpty;

  /// True cuando [esperado] es null (state no requerido) o coincide.
  bool coincideConState(String? esperado) =>
      esperado == null || state == esperado;
}

/// Parsea una URL de callback OAuth (`spotiflac://callback?...`).
///
/// Compara por host (no por esquema) para que cualquier esquema custom
/// funcione, como `verificationGrantFromUrl`. Devuelve null cuando la URL
/// no es un callback o no trae ni `code` ni `error`.
ResultadoOAuth? resultadoOauthDesdeUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host != 'callback') return null;
  final result = ResultadoOAuth(
    code: uri.queryParameters['code'] ?? '',
    state: uri.queryParameters['state'] ?? '',
    error: uri.queryParameters['error'] ?? '',
  );
  if (result.code.isEmpty && result.error.isEmpty) return null;
  return result;
}