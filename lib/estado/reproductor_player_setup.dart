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
mixin ReproductorPlayerSetup on ReproductorLocales {
  /// Configura el player mpv (audio-only), los listeners de posición/
  /// duración/completado/playing/error y el crossfade al final de track.
  void _initPlayer() {
    // AUDIO-ONLY: `vid=no` ANTES de abrir cualquier media para que mpv nunca
    // seleccione una pista de video (un stream fallback video+audio mp4
    // stallea decodificando H.264 sin superficie de video).
    try {
      (_player.platform as dynamic).setProperty('vid', 'no');
    } catch (_) {}
    // media_kit >= 1.2 habilita `cache-on-disk` por defecto; en Android el
    // temp del SO no es escribible y mpv loguea "Failed to create file cache"
    // (la posición avanza sin audio). El caché en memoria alcanza para
    // streaming; el pipeline de descarga maneja el caché en disco.
    try {
      (_player.platform as dynamic).setProperty('cache-on-disk', 'no');
    } catch (_) {}
    // SOLO Android: media_kit usa `ao=opensles` por defecto (roto en varios
    // emuladores/ROMs) y `ao=audiotrack` es la salida moderna que funciona.
    // En escritorio (Windows/Linux/macOS) ese AO NO existe: forzarlo hace que
    // mpv loguee "Audio output audiotrack not found!", no emita audio y
    // complete el media al instante con pos=0 — el guard de EOF lo trata
    // como stream muerto y cada canción "cambia rápido" sin sonido. Dejar el
    // AO por defecto de la plataforma (wasapi/pipewire/coreaudio).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        (_player.platform as dynamic).setProperty('ao', 'audiotrack');
      } catch (_) {}
      // El AO audiotrack negocia salida FLOAT por defecto; varios bridges de
      // audio de emuladores (LDPlayer...) solo manejan PCM16 y renderizan
      // silencio con float. Forzar PCM16 a 48kHz (AudioTrack estándar).
      try {
        (_player.platform as dynamic).setProperty('audio-format', 's16');
      } catch (_) {}
      try {
        (_player.platform as dynamic).setProperty('audio-samplerate', '48000');
      } catch (_) {}
    }
    // TEMP-DIAG: dump de logs mpv a logcat mientras se diagnostican URLs de
    // YouTube muertas.
    _player.stream.log.listen((l) {
      final lvl = l.level.toString();
      if (lvl.contains('error') || lvl.contains('warn') ||
          l.prefix == 'ffmpeg' || l.prefix == 'stream' ||
          l.prefix == 'ao' || l.prefix == 'cplayer' ||
          l.prefix == 'ad' || l.prefix == 'af') {
        debugPrint('[MPV-DIAG] $lvl ${l.prefix}: ${l.text}');
      }
    });
    _subPosicion = _player.stream.position.listen((pos) {
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
    _subDuracion = _player.stream.duration.listen((dur) {
      if (!isClosed) emit(state.copiarCon(duracion: dur));
    });
    _subCompletado = _player.stream.completed.listen((_) {
      if (!isClosed) _onTrackCompletado();
    });
    _subPlaying = _player.stream.playing.listen((playing) {
      if (!isClosed) {
        if (playing) {
          _switchPendiente = false;
          emit(state.copiarCon(estadoReproduccion: EstadoReproduccion.reproduciendo));
        } else if (!_switchPendiente) {
          emit(state.copiarCon(estadoReproduccion: EstadoReproduccion.pausado));
        }
        // Mientras _switchPendiente (track nuevo resolviendo), el player
        // detenido NO degrada el estado visible de buffering.
      }
    });
    _subError = _player.stream.error.listen((error) {
      // Mientras se recupera de un fallo de decode O se cambia de track,
      // ignorar errores residuales del media que se está deteniendo; si no,
      // un switch local↔stream rápido cuenta 3 errores y mata el track nuevo.
      if (_recuperando || _switchPendiente) return;
      // Un recurso fallando (403/expirado/HTML) hace que libmpv lo reabra en
      // loop apretado, spameando "Error decoding audio" para siempre. Romper
      // el loop: tras algunos fallos consecutivos, parar el player y marcar
      // el track como fallido.
      _erroresConsecutivos++;
      if (_erroresConsecutivos >= 3) {
        _erroresConsecutivos = 0;
        final fallido = _queueCubit.state.actual;
        final uriMuerta = _ultimaUriAbierta ?? '';
        if (fallido != null) {
          _urlRotaPorTrack[normalizarId(fallido.id)] = uriMuerta;
        }
        // Un archivo local que no decodifica reabriría para siempre. Parar el
        // media fallido PRIMERO (rompe la tormenta de errores de libmpv),
        // luego borrar el archivo muerto, dropear su resolución cacheada y
        // reintentar el MISMO track. Re-descargas acotadas por track.
        if (fallido != null && uriMuerta.startsWith('file://')) {
          final reintentos =
              (_reintentosArchivoMuerto[normalizarId(fallido.id)] ?? 0) + 1;
          _reintentosArchivoMuerto[normalizarId(fallido.id)] = reintentos;
          if (reintentos > 2) {
            _recuperando = true;
            // Serializado: stop encolado para no pisar un open en vuelo.
            unawaited(_enColaPlayer(() => _player.stop()));
            if (!isClosed) {
              emit(state.copiarCon(estadoReproduccion: EstadoReproduccion.error));
            }
            return;
          }
          final fallidoNorm = normalizarId(fallido.id);
          _recuperando = true;
          _urlRotaPorTrack[fallidoNorm] = uriMuerta;
          _cacheUrlStream.remove(_claveCacheStream(fallidoNorm));
          unawaited(_borrarUriMuerta(uriMuerta));
          // Serializado: el stop (y el re-open que le sigue) espera su turno.
          unawaited(_enColaPlayer(() => _player.stop()));
          unawaited(_openTrack(fallido));
          return;
        }
        unawaited(_enColaPlayer(() => _player.stop()));
        if (!isClosed) {
          emit(state.copiarCon(estadoReproduccion: EstadoReproduccion.error));
        }
      }
    });
  }
}