// ─────────────────────────────────────────────────────────────
// reproductor_audio.dart — Interfaz de audio que usa el reproductor.
//
// Por qué existe: el motor de audio de las plataformas nativas es
// media_kit (libmpv), que NO existe en web. Para que la PWA pueda
// reproducir, la lógica del reproductor (cola, crossfade, precarga,
// watchdog de stall, velocidad, volumen…) no puede depender del
// motor: habla contra esta interfaz, y cada plataforma la implementa.
//
//   · Nativo (Android/iOS/escritorio): reproductor_audio_nativo.dart
//     (media_kit/mpv, con sus propiedades AO, http-header-fields…)
//   · Web (PWA): reproductor_audio_web.dart
//     (HTMLAudioElement del navegador)
//
// La implementación se elige por import condicional, así que el
// compilador de web ni siquiera ve media_kit.
//
// Se conecta con: cubit_reproductor.dart (y sus parts) + los dos
// archivos de implementación.
// Parte del flujo: reproducción (el motor de audio concreto).
// ─────────────────────────────────────────────────────────────

/// Motor de audio con la superficie MÍNIMA que necesita el reproductor.
///
/// Deliberadamente chica: cualquier método de más obliga a implementarlo
/// en dos motores distintos y multiplica las diferencias de conducta.
abstract class ReproductorAudio {
  /// Posición actual del media. Lectura sincrónica: los watchdogs del
  /// reproductor la consultan en cada chequeo (varias veces por segundo).
  Duration get posicion;

  /// ¿Está reproduciendo ahora mismo?
  bool get reproduciendo;

  /// Posición del media (varias veces por segundo).
  Stream<Duration> get flujoPosicion;

  /// Duración del media cuando el motor la conoce.
  Stream<Duration> get flujoDuracion;

  /// El media llegó al final.
  Stream<void> get flujoCompletado;

  /// Cambios de estado reproducir/pausar.
  Stream<bool> get flujoReproduciendo;

  /// Errores del motor (mensaje legible).
  Stream<String> get flujoError;

  /// Log del motor, ya filtrado y formateado (sólo líneas relevantes:
  /// warn/error o los subsistemas de audio/stream). El reproductor sólo
  /// las imprime: el filtro vive en el motor porque sólo él conoce sus
  /// campos. En web no hay motor nativo, así que el flujo queda vacío.
  Stream<String> get flujoLog;

  /// Abre [uri]. [headers] son cabeceras HTTP para el pedido de media; el
  /// motor nativo las aplica, y el navegador NO puede (una limitación real
  /// de web: un stream que exija Referer/User-Agent no va a andar ahí).
  Future<void> abrir(String uri, {Map<String, String>? headers});

  /// Arranca (o reanuda) la reproducción.
  Future<void> reproducir();

  /// Pausa sin perder la posición.
  Future<void> pausar();

  /// Detiene y descarta el media actual.
  Future<void> detener();

  /// Salta a [posicion].
  Future<void> buscar(Duration posicion);

  /// Ajusta el volumen en escala 0.0–1.0 (la escala del estado de la app).
  /// Cada motor la traduce a la suya (mpv usa 0–100).
  Future<void> ponerVolumen(double volumen);

  /// Ajusta la velocidad de reproducción (1.0 = normal).
  Future<void> ponerVelocidad(double velocidad);

  /// Ajustes internos del motor nativo (por ejemplo las propiedades de
  /// mpv: `ao`, `vid`, `http-header-fields`). En web no existe motor
  /// nativo al que aplicarlas, así que es un no-op a propósito.
  Future<void> propiedad(String clave, String valor);

  /// Libera el motor.
  Future<void> dispose();
}
