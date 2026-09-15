// ─────────────────────────────────────────────────────────────
// modelo_calidad_red.dart — Modelos de datos para el medidor
// de calidad de red: enums TipoRed y NivelRed, y la clase
// inmutable EstadoCalidadRed con copiarCon().
//
// Se conecta con: servicio_calidad_red.dart (usa estos modelos).
// Parte del flujo: monitoreo de conexión (Home → barra superior).
// ─────────────────────────────────────────────────────────────

/// Tipo de conexión activa, normalizado para la UI.
enum TipoRed { wifi, movil, ethernet, otra, ninguna }

/// Nivel de calidad medido. El orden importa: se comparan con `index`.
enum NivelRed { desconocido, mala, regular, buena, excelente }

/// Estado inmutable que expone el servicio (para ValueNotifier).
class EstadoCalidadRed {
  final NivelRed nivel;
  final TipoRed tipo;
  final int latenciaMs;
  final bool midiendo;

  const EstadoCalidadRed({
    required this.nivel,
    required this.tipo,
    required this.latenciaMs,
    this.midiendo = false,
  });

  static const inicial = EstadoCalidadRed(
    nivel: NivelRed.desconocido,
    tipo: TipoRed.ninguna,
    latenciaMs: -1,
    midiendo: true,
  );

  bool get hayConexion => nivel != NivelRed.desconocido || tipo != TipoRed.ninguna;

  EstadoCalidadRed copiarCon({NivelRed? nivel, TipoRed? tipo, int? latenciaMs, bool? midiendo}) {
    return EstadoCalidadRed(
      nivel: nivel ?? this.nivel,
      tipo: tipo ?? this.tipo,
      latenciaMs: latenciaMs ?? this.latenciaMs,
      midiendo: midiendo ?? this.midiendo,
    );
  }
}
