// ─────────────────────────────────────────────────────────────
// grant_verificacion.dart — Parsers del grant de verificación de
// sesiones firmadas (Cloudflare Turnstile). Aislados aquí para
// que TANTO el WebView in-app como el servidor loopback de
// escritorio (Windows/Linux) usen EXACTAMENTE la misma lógica
// tolerante. Antes el loopback parseaba la query de forma
// estricta y descartaba el grant cuando la página de zarz la
// concatenaba con `?` en vez de `&` (el modal quedaba abierto).
// Se conecta con: servicio_verificacion.dart (que los re-exporta),
// servidor_callback_escritorio.dart y panel_verificacion_web.dart.
// Parte del flujo: verificación de sesiones (parseo del grant).
// ─────────────────────────────────────────────────────────────

/// Extrae el grant code de una URL de callback de verificación.
///
/// La URL de callback del backend es `spotiflac://session-grant?grant=...`
/// (legacy: `bitly://session-grant?...`), o en desktop el servidor loopback
/// local (`http://127.0.0.1:<puerto>/session-grant?grant=...`). Coincidir por
/// host (o por path /session-grant en loopback) hace funcionar cualquier
/// scheme custom. Devuelve null si la URL no es un callback de session-grant
/// o no tiene el parámetro grant.
String? grantVerificacionDeUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final esLoopback = (uri.host == '127.0.0.1' ||
          uri.host == 'localhost' ||
          uri.host == '[::1]') &&
      uri.path == '/session-grant';
  if (uri.host != 'session-grant' && !esLoopback) return null;
  final raw = uri.queryParameters['grant'];
  if (raw == null || raw.isEmpty) return null;
  return raw.trim();
}

/// Extrae el grant de CUALQUIER cadena que mande la página del challenge
/// (por el puente JS `SpotiflacGrant`, por la URL de navegación o por el
/// servidor loopback). Contrato real de la página de zarz: puede entregar
/// (a) la URL completa de callback (`.../session-grant?grant=gr_...`),
/// (b) una URL con la query malformada (p.ej. `?cb_version=v2grant?grant=X`
/// cuando el callback ya traía query y la página la concatena con `?` en vez
/// de `&`), o (c) el TOKEN PELADO (`gr_...`). El parseo estricto por URL se
/// cae en (b)/(c) y el grant se descartaba en silencio → el modal quedaba
/// colgado mostrando "verificación exitosa" sin cerrar. Este helper tolera
/// los tres casos.
String? grantDeCadena(String cadena) {
  final t = cadena.trim();
  if (t.isEmpty) return null;
  // (a) URL bien formada de callback (deep link o loopback).
  final estricto = grantVerificacionDeUrl(t);
  if (estricto != null) return estricto;
  // (b) URL malformada o query con `grant`/`code`/`token` en cualquier parte
  // de la cadena (regex tolerante a `?` en vez de `&`, a URLs rotas y a
  // cuerpos form-encoded que empiezan directo con `grant=`).
  final m = RegExp('(?:^|[?&])(?:grant|code|token)=([^&\\s"\']+)')
      .firstMatch(t);
  if (m != null) {
    final valor = Uri.decodeComponent(m.group(1)!.trim());
    if (valor.isNotEmpty) return valor;
  }
  // (c) Token pelado: sin scheme ni espacios, parece el código directo.
  if (!t.contains('://') && !t.contains(' ') && !t.contains('/')) {
    return t;
  }
  return null;
}
