// ─────────────────────────────────────────────────────────────
// reproductor_completado.dart — PART de cubit_reproductor.dart:
// manejo del evento `completed` del player: registro del play en
// drift, scrobble, limpieza de streams cacheados y el AVANCE de la
// cola respetando los modos de repetición/shuffle. La detección de
// completaciones FALSAS vive en reproductor_completado_guards.dart y
// la red de seguridad del avance en reproductor_avance_seguro.dart.
// Se conecta con: reproductor_completado_guards.dart (misma library).
// Parte del flujo: reproducción (fin de canción → siguiente).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Completado de track. Mixin aplicado en CubitReproductor.
mixin ReproductorCompletado on ReproductorCompletadoGuards {
  Future<void> _onTrackCompletado() async {
    if (isClosed) return;
    _crossfadingOut = false;

    // Un `completed` tras un open más nuevo pertenece al media que ese open
    // descartó. No se avanza a ciegas, pero SÍ se deja agendada la revisión:
    // si el open nuevo nunca llegó a sonar, la cola no puede quedar muda.
    if (_generacionOpen != _generacionAbiertaEn) {
      _agendarAvanceSeguro('generación de media descartada');
      return;
    }

    final durMs = state.duracion.inMilliseconds;
    final posMs = state.posicion.inMilliseconds;
    final completado = _queueCubit.state.actual;
    final desdeHttp = _ultimaUriAbierta?.startsWith('http://') == true ||
        _ultimaUriAbierta?.startsWith('https://') == true;

    // Guards de completación falsa (stream muerto / preview corto / evento
    // espurio de media_kit): si se dispararon, el track ya se re-abrió o el
    // audio sigue sonando — no avanzar.
    if (_completacionFalsa(completado, desdeHttp, durMs, posMs)) return;

    await _registrarFinDeTrack(completado, durMs);
    await _avanzarColaDesdeCompletado();
  }

  /// Registra el fin de track (historial local + scrobble) y limpia los
  /// archivos temporales del stream del track que terminó. Best-effort: jamás
  /// puede frenar el avance de la cola.
  Future<void> _registrarFinDeTrack(ItemFeed? completado, int durMs) async {
    final cache = _playbackCache;
    if (completado != null && cache != null) {
      unawaited(
        cache.registrarPlay(
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

    final idCompletado = _idActualNormalizado();
    if (idCompletado != null) {
      if (_idsStremeados.remove(idCompletado)) {
        unawaited(_limpiarCacheStream(idCompletado));
      }
      unawaited(_limpiarArchivoTemp(idCompletado));
    }
  }

  /// Avanza la cola por fin de canción respetando los modos de repetición.
  /// Lo llama `_onTrackCompletado` y también la red de seguridad
  /// (reproductor_avance_seguro.dart) cuando un `completed` se descartó y el
  /// player quedó detenido con la cola llena.
  @override
  Future<void> _avanzarColaDesdeCompletado() async {
    if (isClosed) return;
    final colaAntes = _queueCubit.state;
    // Repeat-one re-reproduce el MISMO track en EOF. Pasarlo por siguiente()
    // emitiría un estado con el mismo índice y bloc ≥ 9 descarta estados
    // idénticos — reabrir el track directo. Igual para repeat-all con una
    // sola canción (el wrap a índice 0 también sería un estado idéntico).
    final repetirMismo = colaAntes.modoRepeticion == ModoRepeticion.uno ||
        (colaAntes.modoRepeticion == ModoRepeticion.todos &&
            colaAntes.tracks.length <= 1);
    bool huboSiguiente;
    if (repetirMismo) {
      // Limpiar el flag YA para que una edición de cola posterior (misma key)
      // no dispare un segundo open vía _listenQueue.
      _forzarReopen = false;
      huboSiguiente = true;
      final mismo = colaAntes.actual;
      if (mismo != null) unawaited(_openTrack(mismo));
    } else {
      // El avance va a emitir un índice NUEVO: marcarlo para que _listenQueue
      // reabra en vez de saltar el mismo track.
      _forzarReopen = true;
      huboSiguiente = _queueCubit.siguiente();
    }
    // El crossfade-out pudo dejar el volumen del motor en 0; si el próximo
    // track no llega a abrir, la canción quedaría muda. Devolver el volumen
    // del usuario acá es inofensivo (nadie está sonando en este punto) y
    // garantiza que el siguiente arranque audible.
    if (huboSiguiente) {
      _player.ponerVolumen(_volumenUsuario.clamp(0.0, 1.0));
      return;
    }
    // Cola agotada: si hay internet, radio (autoplay); si no, restaurar
    // volumen y quedarse detenido.
    if (_queueCubit.state.tracks.isNotEmpty) {
      await _intentarAutoplay();
    }
    if (!_queueCubit.state.tieneActual) {
      _player.ponerVolumen(_volumenUsuario.clamp(0.0, 1.0));
    }
  }
}
