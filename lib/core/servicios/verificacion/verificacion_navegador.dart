// ─────────────────────────────────────────────────────────────
// verificacion_navegador.dart — PART de servicio_verificacion.dart:
// salida de emergencia por el NAVEGADOR del sistema. Cuando el
// WebView in-app no sirve (Linux sin webview, o WebView2 no
// disponible) el challenge se abre afuera y el grant vuelve por el
// deep link `spotiflac://session-grant` o por el servidor loopback.
// Se conecta con: servicio_verificacion.dart (misma library) +
// servidor_callback_escritorio + url_launcher.
// Parte del flujo: verificación de sesiones (fallback navegador).
// ─────────────────────────────────────────────────────────────

part of 'servicio_verificacion.dart';

/// Fallback por navegador del sistema. Mixin aplicado en ServicioVerificacion.
mixin VerificacionNavegador on VerificacionKeepalive {
  /// Abre el challenge en el navegador del sistema. El grant vuelve por el deep
  /// link `spotiflac://session-grant` (canal nativo).
  Future<void> _lanzarNavegador(String nombreMostrado, String urlAuth) async {
    _mostrarHintEspera(nombreMostrado);
    try {
      final ok = await launchUrl(
        Uri.parse(urlAuth),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) _lanzamientoFallido();
    } catch (e) {
      _logVerificacion.e('[Verificacion] Error lanzando navegador: $e');
      _lanzamientoFallido();
    }
  }

  /// El navegador no se pudo abrir: terminar la verificación pendiente de
  /// inmediato y liberar el servidor callback desktop para que la espera no
  /// se arrastre hasta el timeout.
  void _lanzamientoFallido() {
    ServidorCallbackEscritorio.instance.cancelar();
    _completarPendiente('');
  }

  void _mostrarHintEspera(String nombreMostrado) {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(
            'Se abrió el navegador — completa el captcha para $nombreMostrado'),
        duration: const Duration(seconds: 5),
      ));
  }
}
