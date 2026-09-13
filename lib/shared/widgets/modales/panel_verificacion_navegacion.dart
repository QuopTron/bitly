// ─────────────────────────────────────────────────────────────
// panel_verificacion_navegacion.dart — PART de
// panel_verificacion_web.dart: construye el NavigationDelegate del
// WebView del challenge Cloudflare: captura el grant desde la URL
// (onUrlChange/onNavigationRequest/onPageStarted/onPageFinished),
// re-marca la página al terminar de cargar y decide cuándo mostrar
// la vista de fallo (solo errores reales del frame principal).
// Se conecta con: panel_verificacion_web.dart (misma library).
// Parte del flujo: verificación de sesiones (navegación del WebView).
// ─────────────────────────────────────────────────────────────

part of 'panel_verificacion_web.dart';

/// Construye el delegate de navegación del WebView de verificación.
///
/// Nota: no usar onUrlChange aquí — webview_win_floating 2.x (Windows)
/// no lo implementa y lanza UnimplementedError al crear el controlador.
/// onPageStarted cubre el mismo caso (chequear el grant en cada URL).
NavigationDelegate _crearDelegate(_PanelVerificacionWebState state) {
  return NavigationDelegate(
    onNavigationRequest: (solicitud) {
      final grant = grantDeCadena(solicitud.url);
      if (grant != null) {
        state._dispararGrant(grant);
        return NavigationDecision.prevent;
      }
      return NavigationDecision.navigate;
    },
    onPageStarted: (url) {
      if (url.contains('session-grant')) {
        debugPrint('[Verificacion] onPageStarted: $url');
      }
      state._alIniciarPagina(url);
      state._chequear(url);
    },
    onPageFinished: (url) {
      if (url.contains('session-grant')) {
        debugPrint('[Verificacion] onPageFinished: $url');
      }
      state._paginaTerminoDeCargar(url);
    },
    onWebResourceError: (error) => state._errorRecursoWeb(error),
  );
}