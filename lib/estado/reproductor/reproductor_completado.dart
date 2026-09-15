// ─────────────────────────────────────────────────────────────
// reproductor_completado.dart — PART de cubit_reproductor.dart:
// manejo del evento `completed` del player: guards de EOF de stream
// muerto y de preview corto (re-resolución del MISMO track vía
// respaldo de descarga), registro del play en drift, scrobble,
// limpieza de streams cacheados y avance de la cola respetando los
// modos de repetición. La limpieza/autoplay viven en
// reproductor_limpieza.dart y reproductor_autoplay.dart.
// Se conecta con: reproductor_limpieza.dart (misma library).
// Parte del flujo: reproducción (fin de canción → siguiente).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Completado de track. Mixin aplicado en CubitReproductor.
mixin ReproductorCompletado on ReproductorCompletadoGuards {
  Future<void> _onTrackCompletado() async {
    if (isClosed) return;
    _crossfadingOut = false;

    // Un `completed` tras un open más nuevo pertenece al media que ese open
    // descartó — avanzar acá hacía que la cola "saltara de 2 en 2".
    if (_generacionOpen != _generacionAbiertaEn) return;

    // media_kit puede emitir un `completed` espurio justo tras open() (p.ej.
    // FLAC locales desencriptados), muchas veces ANTES de parsear la duración
    // real. Solo avanzar con un EOF real: duración conocida (>0) con posición
    // al final. Duración desconocida = prematuro (live/radio no traba).
    final durMs = state.duracion.inMilliseconds;
    final posMs = state.posicion.inMilliseconds;
    final completado = _queueCubit.state.actual;
    final desdeHttp =
        _ultimaUriAbierta?.startsWith('http://') == true ||
        _ultimaUriAbierta?.startsWith('https://') == true;

    // Guards de completación falsa (stream muerto / preview corto):
    // si se dispararon, ya se re-abrió el MISMO track — no avanzar.
    if (_completacionFalsa(completado, desdeHttp, durMs, posMs)) return;

    // Registrar el play en el historial local (Drift) antes de avanzar.
    if (completado != null && _playbackCache != null) {
      unawaited(
        _playbackCache!.registrarPlay(
          trackId: normalizarId(completado.id),
          trackName: completado.name,
          artistName: completado.artists ?? '',
          albumName: completado.albumName,
          durationMs: durMs > 0 ? durMs : null,
          percentage: 100,
        ),
      );
    }

    if (completado != null) {
      unawaited(
        _reportScrobble(
          completado,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          durationSec: state.duracion.inMilliseconds ~/ 1000,
        ),
      );
    }

    // Limpiar caché de stream + archivo temp del track completado.
    final idCompletado = _idActualNormalizado();

    if (idCompletado != null) {
      if (_idsStremeados.remove(idCompletado)) {
        unawaited(_limpiarCacheStream(idCompletado));
      }
      unawaited(_limpiarArchivoTemp(idCompletado));
    }

    // ── Avanzar la cola respetando los modos de repetición ────────────────
    // Repeat-one debe re-reproducir el MISMO track en EOF. Pasarlo por
    // siguiente() emitiría un estado con el mismo índice y bloc ≥ 9 descarta
    // estados idénticos — reabrir el track directo. Igual para repeat-all con
    // una sola canción (el wrap a índice 0 también es un estado idéntico).
    final colaAntes = _queueCubit.state;
    final repetirMismo =
        colaAntes.modoRepeticion == ModoRepeticion.uno ||
        (colaAntes.modoRepeticion == ModoRepeticion.todos &&
            colaAntes.tracks.length <= 1);
    bool huboSiguiente;
    if (repetirMismo) {
      // Limpiar el flag YA para que una edición de cola posterior (misma
      // key) no dispare un segundo open vía _listenQueue.
      _forzarReopen = false;
      huboSiguiente = true;
      final mismo = colaAntes.actual;
      if (mismo != null) unawaited(_openTrack(mismo));
    } else {
      // El avance va a emitir un índice NUEVO: marcarlo para que _listenQueue
      // reabra en vez de saltar el mismo track.
      _forzarReopen = true;
      huboSiguiente = _queueCubit.siguiente();
    } // El crossfade-in lo hace _fadeInAudio() en _openTrack (mpv quedó en 0).
    // Si la cola terminó y hay internet: autoplay; si no, restaurar volumen.
    if (!huboSiguiente && _queueCubit.state.tracks.isNotEmpty) {
      await _intentarAutoplay();
    }
    if (!huboSiguiente && _queueCubit.state.actual == completado) {
      final objetivo = _volumenUsuario.clamp(0.0, 1.0);
      _player.ponerVolumen(objetivo);
    }
  }
}
