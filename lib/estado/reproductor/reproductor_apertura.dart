// ─────────────────────────────────────────────────────────────
// reproductor_apertura.dart — PART de cubit_reproductor.dart:
// apertura de un track: local-first → verificación de sesión firmada
// (Cloudflare) → resolución de stream en vivo → apertura en el
// player con watchdog anti-stall → precargas de vecinos/letras/video
// y reporte de now playing. El detalle de abrir/fallar/vigilar vive
// en reproductor_apertura_helpers.dart; la verificación y los
// reportes en reproductor_verificacion.dart y reproductor_reporte.dart.
// Se conecta con: reproductor_apertura_helpers.dart (misma library).
// Parte del flujo: reproducción (abrir/reproducir un track).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Apertura de tracks. Mixin aplicado en CubitReproductor.
mixin ReproductorApertura on ReproductorAperturaHelpers {
  /// Abre [track] sin poder dejar el reproductor en un estado muerto.
  ///
  /// Quienes abren desde la cola (listener, track pendiente del arranque) no
  /// pueden quedarse sin reacción: si _openTrack lanzara, el error subía como
  /// no manejado y la cola quedaba muda (el miniplayer no aparecía y parecía
  /// que la app se trabó). Acá el fallo se registra y el estado pasa a error,
  /// que es lo que la UI ya sabe mostrar/reintentar.
  Future<void> _abrirTrackSeguro(ItemFeed track) async {
    try {
      await _openTrack(track);
    } catch (e, pila) {
      debugPrint('[Reproductor] no se pudo abrir ${track.id}: $e\n$pila');
      if (!isClosed) {
        emit(state.copiarCon(estadoReproduccion: EstadoReproduccion.error));
      }
    }
  }

  /// Abre y reproduce [track]: archivo local primero, luego stream en vivo
  /// (con verificación de sesión firmada si hace falta), y errores legibles.
  @override
  Future<void> _openTrack(ItemFeed track) async {
    final gen = ++_generacionOpen;
    _claveTrackAbierto = '${track.id}|${track.source}';
    // Un crossfade-out en curso (del track anterior) queda cancelado al abrir
    // uno nuevo; el volumen lo restaura _fadeInAudio() abajo.
    _crossfadingOut = false;
    // El media nuevo aún no confirmó arrancar: los primeros eventos de
    // posición pueden ser residuales del track anterior y NO deben disparar
    // crossfade en el track nuevo.
    _mediaNuevoConfirmado = false;
    await _refreshArchivosLocales();
    // Un _openTrack más nuevo nos supersede mientras estábamos en disco.
    if (gen != _generacionOpen) return;
    _ultimoErrorStream = '';
    _ultimoTipoErrorStream = '';
    _ultimoServicioStream = '';

    // 1. Intentar archivos locales primero (skip de un archivo local que ya
    // falló al decodificar, para que caiga a streaming).
    String? uri = _resolveLocalUri(track);
    if (uri != null) {
      final rota = _urlRotaPorTrack[normalizarId(track.id)];
      if (rota != null && uri == rota) uri = null;
    }
    if (uri != null) _marcarListo(normalizarId(track.id));

    // 2. Si no es local, resolver una URL de stream en vivo.
    if (uri == null) {
      // Gate duro: antes de resolver un stream de una fuente con sesión
      // firmada (Cloudflare), asegurar que su token es usable — si no, abrir
      // el modal de verificación YA para refrescar el token.
      if (!await _ensureSesionParaFuente(track)) {
        // Reset del guard de identidad para que re-tapar este track tras
        // completar la verificación reintente en vez de ser skip.
        _claveTrackAbierto = null;
        final nombre = ServicioVerificacion().nombreFuente(track.source ?? '');
        ServicioVerificacion().mostrarAviso(
          'Sesión de $nombre no verificada — completa la verificación '
          'para reproducir esta canción.',
        );
        return;
      }
      if (gen != _generacionOpen) return;
      // Switch a un track no-local: parar el audio anterior YA para que el
      // usuario no siga oyendo la canción vieja mientras la nueva resuelve
      // (puede tardar 20-30s), y superficiar buffering.
      _switchPendiente = true;
      if (!isClosed) {
        emit(state.copiarCon(estadoReproduccion: EstadoReproduccion.buffering));
      }
      // Serializado: el pause no debe pisar un open en vuelo (crash de
      // media_kit "Callback invoked after it has been deleted").
      unawaited(_enColaPlayer(() => _player.pausar()));
      // Sin internet y sin archivo local: fallar rápido con mensaje claro en
      // vez de esperar el timeout del backend (los RPCs pueden tardar 60s).
      if (!await ServicioConectividad.estaEnLinea()) {
        uri = null;
        _ultimoErrorStream = 'Sin conexión a internet';
        _ultimoTipoErrorStream = 'offline';
      } else {
        uri = await _resolveStreamUrl(track);
      }
      // Un track más nuevo empezó a resolver/abrir mientras esperábamos — no
      // entregar nuestra URL stale al player por encima del track nuevo.
      if (gen != _generacionOpen) return;
    }

    if (uri == null) {
      _switchPendiente = false;
      // El open falló: dropear el guard de identidad para que el usuario
      // pueda tapar el mismo track de nuevo (si no, queda skip silencioso).
      _claveTrackAbierto = null;
      await _manejarFalloOpen(track);
      _recuperando = false;
      return;
    }

    // Check final de supersede justo antes de tocar el player.
    if (gen != _generacionOpen) return;
    // Las URLs googlevideo se reproducen por el proxy local de chunks.
    final String uriPlay = await _localProxyUrl(uri);
    final idNormalizado = normalizarId(track.id);
    _ultimaUriAbierta = uriPlay;
    _erroresConsecutivos = 0;
    // Un track que abrió limpio resetea su budget de reintentos de archivo
    // muerto — excepción: cuando la URI es el MISMO file:// que ya falló, el
    // budget NO se resetea (un archivo corrupto re-descargado a la misma ruta
    // reabriría para siempre).
    if (uriPlay != _urlRotaPorTrack[idNormalizado]) {
      _reintentosArchivoMuerto.remove(idNormalizado);
    }
    _recuperando = false;
    _switchPendiente = false;
    await _abrirEnPlayer(uriPlay, track, idNormalizado);
    _vigilarStall(uriPlay, idNormalizado, track);

    unawaited(_preloadVecinos());

    letrasPrecargadas = null;
    urlVideoPrecargado = null;
    videoPrecargadoListo.value = null;
    precargandoLetras = false;
    precargandoVideo = false;

    unawaited(_preloadLetras(track));
    unawaited(_preloadVideo(track));
    unawaited(_reportNowPlaying(track));
  }
}
