// ─────────────────────────────────────────────────────────────
// reproductor_audio_web.dart — Implementación WEB del audio (PWA)
// sobre el elemento <audio> del navegador.
//
// Por qué no media_kit: su motor es libmpv nativo, así que no existe
// en el navegador. El camino natural en web es HTMLAudioElement, que
// es lo que este archivo envuelve para que el reproductor (cola,
// crossfade, precarga, watchdogs) funcione igual que en nativo.
//
// Dos límites REALES del navegador que conviene tener presentes:
//   · No se pueden mandar cabeceras HTTP en el pedido de media. Un
//     stream que exija Referer/User-Agent (parte de YouTube) no va a
//     andar; se avisa por el flujo de error en vez de fallar callado.
//   · El navegador puede bloquear el arranque automático (política de
//     autoplay) si no hay gesto del usuario. El reproductor abre por un
//     tap, así que normalmente alcanza; si igual lo bloquea, se emite
//     un mensaje claro para que el usuario vuelva a tocar play.
//
// Ojo, esto NO es problema de CORS: un <audio> puede reproducir una URL
// de otro dominio sin cabeceras CORS (a diferencia de fetch/XHR).
//
// Se elige por import condicional desde cubit_reproductor.dart.
// Parte del flujo: reproducción (motor de audio web).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'reproductor_audio.dart';

/// Crea el motor web. Mismo nombre que la implementación nativa.
ReproductorAudio crearReproductorAudio() => ReproductorWeb();

/// Motor de audio del navegador: envuelve un <audio>.
class ReproductorWeb implements ReproductorAudio {
  ReproductorWeb() {
    _audio
      ..preload = 'auto'
      // Sin `crossOrigin`: reproducir es válido cross-domain y pedirlo
      // obligaría a CORS (que varios CDN no mandan).
      ..volume = 1.0;

    _escuchar('timeupdate', () {
      _posicion.add(
        Duration(milliseconds: (_audio.currentTime * 1000).round()),
      );
    });
    _escuchar('durationchange', _emitirDuracion);
    _escuchar('loadedmetadata', _emitirDuracion);
    _escuchar('ended', () => _completado.add(null));
    _escuchar('playing', () => _reproduciendo.add(true));
    _escuchar('play', () => _reproduciendo.add(true));
    _escuchar('pause', () => _reproduciendo.add(false));
    _escuchar('error', _emitirError);
  }

  final web.HTMLAudioElement _audio =
      web.document.createElement('audio') as web.HTMLAudioElement;

  final _posicion = StreamController<Duration>.broadcast();
  final _duracion = StreamController<Duration>.broadcast();
  final _completado = StreamController<void>.broadcast();
  final _reproduciendo = StreamController<bool>.broadcast();
  final _error = StreamController<String>.broadcast();

  /// Registra un listener de un evento del elemento.
  void _escuchar(String evento, void Function() alOcurrir) {
    _audio.addEventListener(evento, ((web.Event _) => alOcurrir()).toJS);
  }

  /// La duración llega como NaN (todavía sin metadata) o Infinity (stream
  /// en vivo): en esos casos no hay duración que reportar.
  void _emitirDuracion() {
    final segundos = _audio.duration;
    if (segundos.isFinite && segundos > 0) {
      _duracion.add(Duration(milliseconds: (segundos * 1000).round()));
    }
  }

  /// Traduce el error del elemento a un mensaje accionable.
  void _emitirError() {
    final codigo = _audio.error?.code ?? 0;
    final detalle = switch (codigo) {
      1 => 'Reproducción cancelada',
      2 => 'Error de red al traer el audio (¿sin conexión?)',
      3 => 'El audio no se pudo decodificar',
      4 =>
        'El audio no está disponible o el enlace no es reproducible '
            '(algunos streams exigen cabeceras que el navegador no puede mandar)',
      _ => 'El navegador no pudo reproducir el audio',
    };
    _error.add(detalle);
  }

  @override
  Duration get posicion =>
      Duration(milliseconds: (_audio.currentTime * 1000).round());

  @override
  bool get reproduciendo => !_audio.paused;

  @override
  Stream<Duration> get flujoPosicion => _posicion.stream;

  @override
  Stream<Duration> get flujoDuracion => _duracion.stream;

  @override
  Stream<void> get flujoCompletado => _completado.stream;

  @override
  Stream<bool> get flujoReproduciendo => _reproduciendo.stream;

  @override
  Stream<String> get flujoError => _error.stream;

  /// No hay motor nativo del que tomar logs: flujo vacío a propósito (el
  /// reproductor sigue imprimiendo lo que llegue, que es nada).
  @override
  Stream<String> get flujoLog => const Stream<String>.empty();

  @override
  Future<void> abrir(String uri, {Map<String, String>? headers}) async {
    if (headers != null && headers.isNotEmpty) {
      // No es fatal, pero explica por qué ciertos streams fallan en web.
      _error.add(
        'Este stream necesita cabeceras que el navegador no puede enviar; '
        'si no suena, probá con otra fuente.',
      );
    }
    _audio.src = uri;
    _audio.load();
  }

  @override
  Future<void> reproducir() async {
    try {
      await _audio.play().toDart;
    } catch (_) {
      // La política de autoplay sólo deja arrancar tras un gesto del usuario.
      _error.add('Tocá play otra vez para permitir la reproducción');
    }
  }

  @override
  Future<void> pausar() async => _audio.pause();

  @override
  Future<void> detener() async {
    _audio.pause();
    _audio.currentTime = 0;
  }

  @override
  Future<void> buscar(Duration posicion) async {
    _audio.currentTime = posicion.inMilliseconds / 1000;
  }

  @override
  Future<void> ponerVolumen(double volumen) async {
    _audio.volume = volumen.clamp(0.0, 1.0);
  }

  @override
  Future<void> ponerVelocidad(double velocidad) async {
    _audio.playbackRate = velocidad;
  }

  /// El navegador no tiene propiedades de motor que ajustar.
  @override
  Future<void> propiedad(String clave, String valor) async {}

  @override
  Future<void> dispose() async {
    try {
      _audio.pause();
      _audio.removeAttribute('src');
      _audio.load();
    } catch (_) {}
    await _posicion.close();
    await _duracion.close();
    await _completado.close();
    await _reproduciendo.close();
    await _error.close();
  }
}
