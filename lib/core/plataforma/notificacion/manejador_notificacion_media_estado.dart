// ─────────────────────────────────────────────────────────────
// manejador_notificacion_media_estado.dart — PART de
// manejador_notificacion_media.dart: mapeos de estado entre los
// strings del puente ('buffering'/'ready'/'completed'/'error'/
// 'loading', 'one'/'all'/'none') y los enums de audio_service
// (AudioProcessingState / AudioServiceRepeatMode), más el parseo
// de artUri asegurando el prefijo file:// para rutas locales.
// Se conecta con: manejador_notificacion_media.dart (misma library).
// Parte del flujo: reproducción (notificación y controles del SO).
// ─────────────────────────────────────────────────────────────

part of 'manejador_notificacion_media.dart';

AudioProcessingState _procesandoDesdeString(String s) {
  switch (s) {
    case 'buffering':
      return AudioProcessingState.buffering;
    case 'ready':
      return AudioProcessingState.ready;
    case 'completed':
      return AudioProcessingState.completed;
    case 'error':
      return AudioProcessingState.error;
    case 'loading':
      return AudioProcessingState.loading;
    default:
      return AudioProcessingState.idle;
  }
}

/// Parsea artUri asegurando que las rutas locales tengan prefijo file://.
Uri? _parsearArtUri(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return Uri.tryParse(trimmed);
  }
  final conEsquema =
      trimmed.startsWith('file://') ? trimmed : 'file://$trimmed';
  return Uri.tryParse(conEsquema);
}

String _modoRepeticionAString(AudioServiceRepeatMode mode) {
  switch (mode) {
    case AudioServiceRepeatMode.one:
      return 'one';
    case AudioServiceRepeatMode.all:
      return 'all';
    default:
      return 'none';
  }
}

AudioServiceRepeatMode _modoRepeticionDesdeString(String s) {
  switch (s) {
    case 'one':
      return AudioServiceRepeatMode.one;
    case 'all':
      return AudioServiceRepeatMode.all;
    default:
      return AudioServiceRepeatMode.none;
  }
}