// ─────────────────────────────────────────────────────────────
// reproductor_player_setup.dart — PART de cubit_reproductor.dart:
// configuración del player mpv (audio-only) y sus listeners:
// propiedades AO/audio-format para emuladores, dump de logs mpv,
// listener de posición con el crossfade-out al final del track (con
// guard de generación para el muteo intermitente), duración,
// completado, playing y el loop-breaker de errores de decode.
// Se conecta con: reproductor_locales.dart (misma library).
// Parte del flujo: reproducción (arranque del player).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Configuración del player mpv. Mixin aplicado en CubitReproductor.
mixin ReproductorPlayerSetup on ReproductorPlayerErrores {
  /// Configura el player mpv (audio-only), los listeners de posición/
  /// duración/completado/playing/error y el crossfade al final de track.
  void _initPlayer() {
    // AUDIO-ONLY: `vid=no` ANTES de abrir cualquier media para que mpv nunca
    // seleccione una pista de video (un stream fallback video+audio mp4
    // stallea decodificando H.264 sin superficie de video).
    // (En web `propiedad` es un no-op: el navegador no tiene propiedades de
    // motor que ajustar, y el try/catch interno ya absorbe cualquier fallo.)
    unawaited(_player.propiedad('vid', 'no'));
    // media_kit >= 1.2 habilita `cache-on-disk` por defecto; en Android el
    // temp del SO no es escribible y mpv loguea "Failed to create file cache"
    // (la posición avanza sin audio). El caché en memoria alcanza para
    // streaming; el pipeline de descarga maneja el caché en disco.
    unawaited(_player.propiedad('cache-on-disk', 'no'));
    // SOLO Android: media_kit usa `ao=opensles` por defecto (roto en varios
    // emuladores/ROMs) y `ao=audiotrack` es la salida moderna que funciona.
    // En escritorio (Windows/Linux/macOS) ese AO NO existe: forzarlo hace que
    // mpv loguee "Audio output audiotrack not found!", no emita audio y
    // complete el media al instante con pos=0 — el guard de EOF lo trata
    // como stream muerto y cada canción "cambia rápido" sin sonido. Dejar el
    // AO por defecto de la plataforma (wasapi/pipewire/coreaudio).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_player.propiedad('ao', 'audiotrack'));
      // El AO audiotrack negocia salida FLOAT por defecto; varios bridges de
      // audio de emuladores (LDPlayer...) solo manejan PCM16 y renderizan
      // silencio con float. Forzar PCM16 a 48kHz (AudioTrack estándar).
      unawaited(_player.propiedad('audio-format', 's16'));
      unawaited(_player.propiedad('audio-samplerate', '48000'));
    }
    // TEMP-DIAG: dump de logs mpv a logcat mientras se diagnostican URLs de
    // YouTube muertas.
    _player.flujoLog.listen((l) => debugPrint('[MPV-DIAG] $l'));
    _subPosicion = _player.flujoPosicion.listen((pos) {
      if (!isClosed) emit(state.copiarCon(posicion: pos));
      // Guard de media nuevo: el primer evento de posición tras un open()
      // debe venir del media ACTUAL arrancando (~0s). Un evento residual del
      // track ANTERIOR (encolado en el stream de media_kit) llega con valor
      // ALTO justo después del open y, con duraciones parecidas, disparaba el
      // crossfade-out en el track NUEVO a los ~2s dejándolo mudo el resto de
      // la canción. Hasta confirmar posición baja, NO se toca el crossfade.
      if (!_mediaNuevoConfirmado) {
        if (pos <= const Duration(seconds: 2)) {
          _mediaNuevoConfirmado = true;
        } else {
          // Posición alta sin haber confirmado el arranque = residual del
          // track anterior; ignorarlo (no dispara crossfade ni nada más).
          return;
        }
      }
      // Crossfade: cerca del final del track, empezar fade-out del volumen.
      // Guard: solo cuando el media actual está totalmente abierto
      // (_generacionOpen == _generacionAbiertaEn) Y ya confirmó arrancar
      // desde ~0 (_mediaNuevoConfirmado). Sin esto, un evento de posición
      // OBSOLETO del track anterior puede llegar justo después de que el
      // siguiente publique su duración — con duraciones parecidas el
      // crossfade se disparaba en el track NUEVO a los ~2-3s y lo dejaba
      // mudo el resto de la canción (el muteo intermitente "a veces").
      if (_crossfadeHabilitado &&
          !_crossfadingOut &&
          _generacionOpen == _generacionAbiertaEn) {
        final dur = state.duracion;
        if (dur > Duration.zero &&
            dur - pos <= _crossfadeInicioAntesDelFinal &&
            dur - pos > Duration.zero) {
          _crossfadingOut = true;
          _fadeVolumen(0, _duracionCrossfade);
          // Lanzar YA la resolución completa del siguiente track para que esté
          // listo al completar el actual (sin esto la resolución empieza
          // después del completado — agregando latencia de red al gap).
          _eagerPreloadNext();
        }
      }
    });
    _subDuracion = _player.flujoDuracion.listen((dur) {
      if (!isClosed) emit(state.copiarCon(duracion: dur));
    });
    _subCompletado = _player.flujoCompletado.listen((_) {
      if (!isClosed) _onTrackCompletado();
    });
    _subPlaying = _player.flujoReproduciendo.listen((playing) {
      if (!isClosed) {
        if (playing) {
          _switchPendiente = false;
          emit(
            state.copiarCon(
              estadoReproduccion: EstadoReproduccion.reproduciendo,
            ),
          );
        } else if (!_switchPendiente) {
          emit(state.copiarCon(estadoReproduccion: EstadoReproduccion.pausado));
        }
        // Mientras _switchPendiente (track nuevo resolviendo), el player
        // detenido NO degrada el estado visible de buffering.
      }
    });

    _subError = _player.flujoError.listen(_manejarErrorPlayer);
  }
}
