// ─────────────────────────────────────────────────────────────
// estado_sesion_firmada.dart — Snapshot del estado de la sesión
// firmada de una extensión (autenticado/expiración/ids) tal como
// lo reporta el backend Go vía getSignedSessionStatus.
// Se conecta con: backend_go (mixins de acciones/sesiones firmadas).
// Parte del flujo: verificación de sesiones (Cloudflare) al arrancar.
// ─────────────────────────────────────────────────────────────

/// Estado de la sesión firmada de una extensión.
class EstadoSesionFirmada {
  final bool autenticado;
  final String? expiraEn;
  final String? installId;
  final String? sessionId;
  final String? error;

  const EstadoSesionFirmada({
    this.autenticado = false,
    this.expiraEn,
    this.installId,
    this.sessionId,
    this.error,
  });

  factory EstadoSesionFirmada.desdeJson(Map<String, dynamic> json) {
    return EstadoSesionFirmada(
      autenticado: json['authenticated'] == true,
      expiraEn: json['expires_at'] as String?,
      installId: json['install_id'] as String?,
      sessionId: json['session_id'] as String?,
      error: json['error'] as String?,
    );
  }
}