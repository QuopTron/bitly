// ─────────────────────────────────────────────────────────────
// reproductor_audio_web_eventos.dart — PART de reproductor_audio_web.dart:
// cableado de los eventos del <audio> a los streams públicos del
// motor (tiempo, duración, fin, play/pause y error) y traducción
// del error del elemento a un mensaje accionable.
// Se conecta con: reproductor_audio_web.dart (misma library).
// Parte del flujo: reproducción (motor de audio web).
// ─────────────────────────────────────────────────────────────

part of 'reproductor_audio_web.dart';

/// Conecta los eventos del elemento a los streams que consume el player.
void _conectarEventos(ReproductorWeb r) {
  _escuchar(r, 'timeupdate', () {
    r._posicion.add(
      Duration(milliseconds: (r._audio.currentTime * 1000).round()),
    );
  });
  _escuchar(r, 'durationchange', () => _emitirDuracion(r));
  _escuchar(r, 'loadedmetadata', () => _emitirDuracion(r));
  _escuchar(r, 'ended', () => r._completado.add(null));
  _escuchar(r, 'playing', () => r._reproduciendo.add(true));
  _escuchar(r, 'play', () => r._reproduciendo.add(true));
  _escuchar(r, 'pause', () => r._reproduciendo.add(false));
  _escuchar(r, 'error', () => _emitirError(r));
}

/// Registra un listener de un evento del elemento.
void _escuchar(ReproductorWeb r, String evento, void Function() alOcurrir) {
  r._audio.addEventListener(evento, ((web.Event _) => alOcurrir()).toJS);
}

/// La duración llega como NaN (todavía sin metadata) o Infinity (stream
/// en vivo): en esos casos no hay duración que reportar.
void _emitirDuracion(ReproductorWeb r) {
  final segundos = r._audio.duration;
  if (segundos.isFinite && segundos > 0) {
    r._duracion.add(Duration(milliseconds: (segundos * 1000).round()));
  }
}

/// Traduce el error del elemento a un mensaje accionable.
void _emitirError(ReproductorWeb r) {
  final codigo = r._audio.error?.code ?? 0;
  final s = L10n.actual.servicio;
  final detalle = switch (codigo) {
    1 => s.audioWebCancelada,
    2 => s.audioWebRed,
    3 => s.audioWebDecodificar,
    4 => s.audioWebNoDisponible,
    _ => s.audioWebGenerico,
  };
  r._error.add(detalle);
}
