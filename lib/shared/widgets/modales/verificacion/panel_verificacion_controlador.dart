// ─────────────────────────────────────────────────────────────
// panel_verificacion_controlador.dart — PART de
// panel_verificacion_web.dart: construye el WebViewController del
// challenge Cloudflare: JS unrestricted + el puente `SpotiflacGrant`
// que captura el grant (REQUERIDO, Chromium descarta la navegación
// custom-scheme iniciada por script) + el delegate de navegación.
// Separado para mantener cada archivo dentro del límite de líneas.
// Se conecta con: panel_verificacion_web.dart (misma library).
// Parte del flujo: verificación de sesiones (controlador del WebView).
// ─────────────────────────────────────────────────────────────

part of 'panel_verificacion_web.dart';

/// Construye el controlador WebView del challenge Cloudflare.
WebViewController _crearControlador(_PanelVerificacionWebState state) {
  // Windows (webview_win_floating / WebView2): fijar una carpeta de datos de
  // usuario escribible. Sin esto el WebView2 intenta crear su carpeta junto al
  // ejecutable, y con la app instalada en %LOCALAPPDATA%\Programs\Bitly puede
  // fallar o quedar en un directorio de solo lectura → el WebView nunca
  // renderiza (el modal abre pero en blanco). La carpeta va en %LOCALAPPDATA%
  // que siempre es escribible por usuario.
  if (Platform.isWindows) {
    final base =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        '';
    final carpetaDatos = base.isEmpty
        ? null
        : '$base\\Bitly\\webview_data';
    return WebViewController.fromPlatformCreationParams(
      WindowsPlatformWebViewControllerCreationParams(
        userDataFolder: carpetaDatos,
      ),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'SpotiflacGrant',
        onMessageReceived: (mensaje) {
          // La página de zarz postea el grant como URL completa, URL con query
          // malformada o token pelado — grantDeCadena tolera los tres casos.
          final grant = grantDeCadena(mensaje.message);
          debugPrint('[Verificacion] JS bridge mensaje: '
              '${mensaje.message.length > 120 ? mensaje.message.substring(0, 120) : mensaje.message} '
              '→ grant: ${grant == null ? 'null' : 'OK'}');
          if (grant != null) state._dispararGrant(grant);
        },
      )
      ..setNavigationDelegate(_crearDelegate(state));
  }
  return WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..addJavaScriptChannel(
      'SpotiflacGrant',
      onMessageReceived: (mensaje) {
        // La página de zarz postea el grant como URL completa, URL con query
        // malformada o token pelado — grantDeCadena tolera los tres casos.
        final grant = grantDeCadena(mensaje.message);
        debugPrint('[Verificacion] JS bridge mensaje: '
            '${mensaje.message.length > 120 ? mensaje.message.substring(0, 120) : mensaje.message} '
            '→ grant: ${grant == null ? 'null' : 'OK'}');
        if (grant != null) state._dispararGrant(grant);
      },
    )
    ..setNavigationDelegate(_crearDelegate(state));
}