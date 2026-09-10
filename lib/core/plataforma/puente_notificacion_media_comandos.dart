// ─────────────────────────────────────────────────────────────
// puente_notificacion_media_comandos.dart — PART de
// puente_notificacion_media.dart: traduce los comandos que llegan
// del SO (notificación media / controles del sistema) a las
// acciones de los cubits reales de reproducción: play, pause,
// playPause, next, prev, stop, seek, shuffle y repeat.
// Se conecta con: puente_notificacion_media.dart (misma library) +
// estado (CubitCola + CubitReproductor) + inyeccion.
// Parte del flujo: reproducción (notificación y controles del SO).
// ─────────────────────────────────────────────────────────────

part of 'puente_notificacion_media.dart';

/// Procesa un mensaje del isolate de audio_service: registro del handler
/// o comando de control (play/pause/seek/next/prev/shuffle/repeat).
void _onMensajeControl(PuenteNotificacionMedia puente, dynamic raw) {
  if (raw is! Map) return;
  final type = raw['@type'];
  if (type == 'register') {
    puente._puertoEstadoHandler = raw['sendPort'] as SendPort?;
    puente._pushEstado(force: true);
    return;
  }
  if (type != 'command') return;
  final cmd = (raw['cmd'] ?? '').toString();
  final cola = di.sl<CubitCola>();
  final reproductor = di.sl<CubitReproductor>();
  switch (cmd) {
    case 'play':
      reproductor.reproducir();
    case 'pause':
      reproductor.pausar();
    case 'playPause':
      reproductor.alternarReproduccion();
    case 'next':
      cola.siguiente();
    case 'prev':
      cola.anterior();
    case 'stop':
      reproductor.pausar();
    case 'seek':
      final ms = (raw['ms'] as num?)?.toInt() ?? 0;
      if (ms >= 0) reproductor.buscar(Duration(milliseconds: ms));
    case 'shuffle':
      cola.setShuffle((raw['on'] == true));
    case 'repeat':
      cola.setModoRepeticionStr((raw['mode'] ?? 'none').toString());
  }
}