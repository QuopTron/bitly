// ─────────────────────────────────────────────────────────────
// modelo_soulseek.dart — Modelos de datos para el servicio de
// Soulseek: MotivoSoulseek (razón del rechazo) y ResultadoSoulseek
// (resultado del botón "Siguiente").
//
// Se conecta con: servicio_soulseek.dart (usa estos modelos).
// Parte del flujo: Ajustes → Soulseek.
// ─────────────────────────────────────────────────────────────

/// Motivo accionable del rechazo del backend.
enum MotivoSoulseek { nombreTomado, nombreInvalido, ninguno }

/// Resultado del botón "Siguiente".
class ResultadoSoulseek {
  final bool ok;
  final String mensaje;
  final String usuario;
  final String password;
  final bool passwordGenerada;
  final MotivoSoulseek motivo;

  const ResultadoSoulseek({
    required this.ok,
    required this.mensaje,
    this.usuario = '',
    this.password = '',
    this.passwordGenerada = false,
    this.motivo = MotivoSoulseek.ninguno,
  });

  bool get problemaDeNombre =>
      motivo == MotivoSoulseek.nombreTomado ||
      motivo == MotivoSoulseek.nombreInvalido;

  String get motivoClave {
    switch (motivo) {
      case MotivoSoulseek.nombreTomado: return 'nombre_tomado';
      case MotivoSoulseek.nombreInvalido: return 'nombre_invalido';
      case MotivoSoulseek.ninguno: return '';
    }
  }
}
