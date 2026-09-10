// ─────────────────────────────────────────────────────────────
// notificacion_media_helpers.dart — Mapeos de estado para la
// notificación media: traduce el estado de reproducción y el modo
// de repetición del motor (EstadoAudioReproductor / ModoRepeticion)
// a los strings que entiende el handler del isolate de audio_service
// ('buffering'/'ready'/'error', 'one'/'all'/'none').
// Se conecta con: puente_notificacion_media.dart (envío de estado).
// Parte del flujo: reproducción (notificación y controles del SO).
// ─────────────────────────────────────────────────────────────

import '../../core/cache/estado_cola.dart';
import '../../core/cache/estado_reproductor.dart';

/// Traduce el estado de reproducción del motor a string de audio_service.
String procesandoDesde(EstadoAudioReproductor reproductor) {
  switch (reproductor.estadoReproduccion) {
    case EstadoReproduccion.buffering:
      return 'buffering';
    case EstadoReproduccion.error:
      return 'error';
    default:
      return 'ready';
  }
}

/// Traduce el modo de repetición de la cola a string de audio_service.
String repeticionDesde(ModoRepeticion modo) {
  switch (modo) {
    case ModoRepeticion.uno:
      return 'one';
    case ModoRepeticion.todos:
      return 'all';
    default:
      return 'none';
  }
}