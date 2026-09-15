// ─────────────────────────────────────────────────────────────
// verificacion_fuentes.dart — PART de servicio_verificacion.dart:
// API de alto nivel para firmar la sesión de UNA fuente. Ofrece la
// vía visible (modal in-app, usada por reproducción/descarga/búsqueda)
// y la vía silenciosa (setup, para no abrir challenges en cadena).
// Se conecta con: servicio_verificacion.dart (misma library) +
// contrato_backend.
// Parte del flujo: verificación de sesiones (firmar una fuente).
// ─────────────────────────────────────────────────────────────

part of 'servicio_verificacion.dart';

/// Firmado de una fuente puntual. Mixin aplicado en ServicioVerificacion.
mixin VerificacionFuentes on VerificacionMostrar, VerificacionSilenciosa {
  /// Verifica una fuente abriendo el MODAL in-app (usado por reproducción,
  /// descarga y búsqueda). La verificación es la autorización que el servicio
  /// de música pide para permitir reproducir/descargar su contenido: cuando la
  /// extensión la necesita, el modal aparece DENTRO de la app (nunca se
  /// oculta), el usuario resuelve el captcha, la app rescata el token, cierra
  /// el modal y continúa exactamente donde estaba. El modal incluye un texto
  /// que explica al usuario por qué aparece.
  ///
  /// mostrarVerificacion intenta primero el auto-pase de Turnstile (modo
  /// managed, que Cloudflare resuelve solo sin interacción); si no auto-pasa,
  /// cae al dialog visible. Devuelve true solo si la sesión quedó firmada.
  ///
  /// [intentarAuto] false (setup) abre el WebView visible de inmediato.
  Future<bool> verificarFuenteNoIntrusiva(
    String extId,
    String nombreMostrado,
    String urlAuth, {
    bool intentarAuto = true,
  }) async {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted || _deshabilitado) return false;
    final grant = await mostrarVerificacion(
      extId: extId,
      nombreMostrado: nombreMostrado,
      urlAuth: urlAuth,
      intentarAuto: intentarAuto,
    );
    if (grant == null || grant.isEmpty) return false;
    try {
      final backend = di.sl<BackendService>();
      final ok = await backend.completeSignedSessionGrant(extId, grant);
      if (ok) _necesitaVerificacion.remove(extId);
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Intenta firmar UNA fuente de forma SILENCIOSA (WebView oculto, sin
  /// modal). Devuelve true solo si el grant se obtuvo y la sesión quedó
  /// firmada contra Go. Usado por el setup para no abrir challenges en cadena.
  Future<bool> verificarFuenteSilenciosa(String extId, String urlAuth) async {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted || _deshabilitado) return false;
    final grant = await _intentarSilencioso(urlAuth, ctx);
    if (grant == null || grant.isEmpty) return false;
    try {
      final backend = di.sl<BackendService>();
      return await backend.completeSignedSessionGrant(extId, grant);
    } catch (e) {
      _logVerificacion.w(
          '[Verificacion] verificarFuenteSilenciosa $extId error: $e');
      return false;
    }
  }
}
