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
      duracion.inMilliseconds > 0 ? posicion.inMilliseconds / duracion.inMilliseconds : 0.0;

  final double volumen;

  /// Multiplicador de velocidad de reproducción (0.5x–2.0x). Persistido en el
  /// estado para que la UI lo muestre/cambie y se re-aplique al abrir tracks.
  final double velocidad;

  final EstadoReproduccion estadoReproduccion;

  /// Razón legible de por qué la reproducción se atascó/falló, visible en la
  /// UI (p.ej. "Sesión de Deezer no verificada") para que un fallo de
  /// resolución no sea silencioso.
  final String? mensajeError;

  bool get estaReproduciendo => estadoReproduccion == EstadoReproduccion.reproduciendo;

  const EstadoAudioReproductor({
    this.posicion = Duration.zero,
    this.duracion = Duration.zero,
    this.volumen = 1.0,
    this.velocidad = 1.0,
    this.estadoReproduccion = EstadoReproduccion.pausado,
    this.mensajeError,
  });

  EstadoAudioReproductor copiarCon({
    Duration? posicion,
    Duration? duracion,
    double? volumen,
    double? velocidad,
    EstadoReproduccion? estadoReproduccion,
    String? mensajeError,
  }) =>
      EstadoAudioReproductor(
        posicion: posicion ?? this.posicion,
        duracion: duracion ?? this.duracion,
        volumen: volumen ?? this.volumen,
        velocidad: velocidad ?? this.velocidad,
        estadoReproduccion: estadoReproduccion ?? this.estadoReproduccion,
        mensajeError: mensajeError ?? this.mensajeError,
      );

  @override
  List<Object?> get props => [posicion, duracion, volumen, velocidad, estadoReproduccion, mensajeError];
}