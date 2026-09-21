// ─────────────────────────────────────────────────────────────
// estado_reproductor.dart — Estado del reproductor de audio:
// posición, duración, volumen, velocidad, estado de reproducción y
// mensaje de error (para no fallar en silencio).
// Se conecta con: PlayerCubit (estado del cubit).
// Parte del flujo: reproducción (miniplayer, notificación, player).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

enum EstadoReproduccion { reproduciendo, pausado, buffering, error }

class EstadoAudioReproductor extends Equatable {
  final Duration posicion;
  final Duration duracion;

  double get progreso =>
      duracion.inMilliseconds > 0
          ? posicion.inMilliseconds / duracion.inMilliseconds
          : 0.0;

  final double volumen;

  /// Multiplicador de velocidad de reproducción (0.5x–2.0x). Persistido en el
  /// estado para que la UI lo muestre/cambie y se re-aplique al abrir tracks.
  final double velocidad;

  final EstadoReproduccion estadoReproduccion;

  /// CÓDIGO de por qué la reproducción falló (null = sin fallo). El estado no
  /// guarda texto: quien lo muestre lo traduce con l10n, así el motivo sigue el
  /// idioma activo en vez de quedar congelado en el que falló.
  final CodigoErrorReproductor? codigoError;

  bool get estaReproduciendo =>
      estadoReproduccion == EstadoReproduccion.reproduciendo;

  const EstadoAudioReproductor({
    this.posicion = Duration.zero,
    this.duracion = Duration.zero,
    this.volumen = 1.0,
    this.velocidad = 1.0,
    this.estadoReproduccion = EstadoReproduccion.pausado,
    this.codigoError,
  });

  EstadoAudioReproductor copiarCon({
    Duration? posicion,
    Duration? duracion,
    double? volumen,
    double? velocidad,
    EstadoReproduccion? estadoReproduccion,
    CodigoErrorReproductor? codigoError,
  }) => EstadoAudioReproductor(
    posicion: posicion ?? this.posicion,
    duracion: duracion ?? this.duracion,
    volumen: volumen ?? this.volumen,
    velocidad: velocidad ?? this.velocidad,
    estadoReproduccion: estadoReproduccion ?? this.estadoReproduccion,
    codigoError: codigoError ?? this.codigoError,
  );

  @override
  List<Object?> get props => [
    posicion,
    duracion,
    volumen,
    velocidad,
    estadoReproduccion,
    codigoError,
  ];
}

/// Por qué falló la resolución de un track. Código, no texto: la UI lo traduce.
enum CodigoErrorReproductor {
  /// La fuente exige verificación (Cloudflare/sesión firmada) antes de sonar.
  sesionNoVerificada,

  /// El proveedor está saturado (429).
  proveedorSaturado,

  /// No hay conexión y no hay copia descargada.
  sinConexion,

  /// Se agotaron las fuentes sin un stream original utilizable.
  sinStream,
}
