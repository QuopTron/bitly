// ─────────────────────────────────────────────────────────────
// panel_verificacion_callbacks.dart — PART de panel_verificacion_web.dart:
// callbacks del panel — chequeo tolerante de la URL en busca del grant,
// disparo único del grant al padre, inyección del interceptor/branding
// y decisión de mostrar la vista de fallo (solo errores reales del
// frame principal). Reciben el estado del panel.
// Se conecta con: panel_verificacion_web.dart (misma library) +
// servicio_verificacion (grantDeCadena) + branding (JS).
// Parte del flujo: verificación de sesiones (captcha Cloudflare).
// ─────────────────────────────────────────────────────────────

part of 'panel_verificacion_web.dart';

void _chequear(_PanelVerificacionWebState st, String? url) {
  if (url == null) return;
  // Parser TOLERANTE (mismo que el loopback y el puente JS): la URL de
  // callback de zarz suele llegar con la query malformada
  // (`?cb_version=v2grant?grant=gr_...`) y el parseo estricto la descartaba
  // en silencio → el modal quedaba abierto aunque la verificación hubiera
  // terminado bien. En Windows es la ruta principal (la página navega al
  // callback loopback), por eso ahí no cerraba y en Android sí.
  final grant = grantDeCadena(url);
  if (grant != null) _dispararGrant(st, grant);
}

void _dispararGrant(_PanelVerificacionWebState st, String grant) {
  if (st._grantDisparado) return;
  st._grantDisparado = true;
  st._timerCarga?.cancel();
  debugPrint('[Verificacion] GRANT capturado en WebView ($grant) → alObtenerGrant');
  st.widget.alObtenerGrant(grant);
}

/// Re-marca el captcha a Bitly (JS en panel_verificacion_branding.dart) e
/// inyecta el interceptor de red que rescata el grant de la respuesta del
/// challenge. El interceptor corre ANTES de que la página haga su fetch de
/// verificación (que ocurre recién cuando el usuario resuelve el captcha),
/// así el hook queda puesto a tiempo.
void _aplicarBranding(_PanelVerificacionWebState st, String url) {
  if (url.isEmpty || !url.contains('zarz.moe')) return;
  unawaited(st._controlador.runJavaScript(_jsInterceptorGrant));
  unawaited(st._controlador.runJavaScript(_jsBrandingBitly));
}

/// onPageStarted: intenta inyectar el interceptor lo antes posible (por si
/// el documento nuevo ya está activo). Es idempotente.
void _alIniciarPagina(_PanelVerificacionWebState st, String url) {
  if (url.contains('zarz.moe')) {
    unawaited(st._controlador.runJavaScript(_jsInterceptorGrant));
  }
}

/// onPageFinished: marca la página cargada + branding.
void _paginaTerminoDeCargar(_PanelVerificacionWebState st, String url) {
  _chequear(st, url);
  st._marcarCargada();
  _aplicarBranding(st, url);
}

/// onWebResourceError: solo fallo para errores del frame principal.
void _errorRecursoWeb(_PanelVerificacionWebState st, WebResourceError error) {
  if (error.isForMainFrame != false) {
    _logPanel.e('[Verificacion] Error WebView: '
        '${error.description} code=${error.errorCode} url=${error.url}');

    // El redirect spotiflac:// reporta ERR_UNKNOWN_URL_SCHEME (varía por
    // dispositivo); el delegado de navegación ya capturó el grant.
    final esErrorScheme = error.errorCode == -10 ||
        error.description.toUpperCase().contains('UNKNOWN_URL_SCHEME') ||
        (error.url ?? '').startsWith('spotiflac://');
    if (!esErrorScheme) {
      st._marcarFallo();
    }
  }
}
