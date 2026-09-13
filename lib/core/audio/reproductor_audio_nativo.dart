// ─────────────────────────────────────────────────────────────
// reproductor_audio_nativo.dart — Implementación NATIVA del audio
// (Android/iOS/Windows/Linux/macOS) sobre media_kit (libmpv).
//
// Es el MISMO motor y la MISMA configuración que tenía el cubit
// cuando hablaba con media_kit directamente: nivel de log debug
// (para ver los 403 de mpv) y las propiedades que se aplicaban a
// mano (ver reproductor_player_setup.dart). Nada de esto cambia
// para el usuario de las plataformas nativas.
//
// Se elige por import condicional desde cubit_reproductor.dart: la
// compilación web usa reproductor_audio_web.dart y no ve media_kit.
//
// Parte del flujo: reproducción (motor de audio nativo).
// ─────────────────────────────────────────────────────────────

import 'package:media_kit/media_kit.dart';

import 'reproductor_audio.dart';

/// Crea el motor nativo. Es el punto de entrada que usa el
/// reproductor (mismo nombre en las dos implementaciones).
ReproductorAudio crearReproductorAudio() => ReproductorMediaKit();

/// Motor de audio nativo: envuelve el [Player] de media_kit.
class ReproductorMediaKit implements ReproductorAudio {
  final Player _player = Player(
    configuration: const PlayerConfiguration(logLevel: MPVLogLevel.debug),
  );

  @override
  Duration get posicion => _player.state.position;

  @override
  bool get reproduciendo => _player.state.playing;

  @override
  Stream<Duration> get flujoPosicion => _player.stream.position;

  @override
  Stream<Duration> get flujoDuracion => _player.stream.duration;

  @override
  Stream<void> get flujoCompletado => _player.stream.completed;

  @override
  Stream<bool> get flujoReproduciendo => _player.stream.playing;

  @override
  Stream<String> get flujoError => _player.stream.error;

  /// El log de mpv llega con campos separados. Se filtra AQUÍ (no en el
  /// reproductor) porque sólo el motor conoce esos campos: el reproductor
  /// recibe las líneas ya relevantes y sólo las imprime. El mpv viene en
  /// nivel debug, así que sin este filtro el log sería una inundación.
  @override
  Stream<String> get flujoLog => _player.stream.log
      .where((l) {
        final lvl = l.level.toString();
        return lvl.contains('error') ||
            lvl.contains('warn') ||
            l.prefix == 'ffmpeg' ||
            l.prefix == 'stream' ||
            l.prefix == 'ao' ||
            l.prefix == 'cplayer' ||
            l.prefix == 'ad' ||
            l.prefix == 'af';
      })
      .map((l) => '${l.level} ${l.prefix}: ${l.text}');

  @override
  Future<void> abrir(String uri, {Map<String, String>? headers}) =>
      _player.open(Media(uri, httpHeaders: headers));

  @override
  Future<void> reproducir() => _player.play();

  @override
  Future<void> pausar() => _player.pause();

  @override
  Future<void> detener() => _player.stop();

  @override
  Future<void> buscar(Duration posicion) => _player.seek(posicion);

  /// La interfaz usa 0.0–1.0, pero la propiedad `volume` de mpv va de 0 a
  /// 100 (default 100). Sin esta conversión la app reproducía a ~1%:
  /// técnicamente "reproduciendo" pero inaudible.
  @override
  Future<void> ponerVolumen(double volumen) =>
      _player.setVolume(volumen.clamp(0.0, 1.0) * 100);

  @override
  Future<void> ponerVelocidad(double velocidad) => _player.setRate(velocidad);

  @override
  Future<void> propiedad(String clave, String valor) async {
    // Las propiedades de mpv se aplican sobre la plataforma del player. El
    // cast dinámico es el mismo que usaba el reproductor: media_kit no las
    // expone tipadas y algunas solo existen en ciertas versiones.
    try {
      await (_player.platform as dynamic).setProperty(clave, valor);
    } catch (_) {}
  }

  @override
  Future<void> dispose() => _player.dispose();
}
