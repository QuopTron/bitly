// ─────────────────────────────────────────────────────────────
// reproductor_apertura_helpers.dart — PART de cubit_reproductor.dart:
// helpers de apertura de track: abrir el media en el player mpv
// (headers HTTP directo, open, play, velocidad, fade-in), el
// watchdog anti-stall (un open de red que no avanza de 00:00 se
// re-resuelve una vez) y el reporte legible del fallo de resolución
// (verificación / 429 / offline / genérico).
// Se conecta con: reproductor_reporte.dart (misma library).
// Parte del flujo: reproducción (abrir/reproducir un track).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Helpers de apertura. Mixin aplicado en CubitReproductor.
mixin ReproductorAperturaHelpers on ReproductorReporte {
  /// Reapertura de un track — la implementación concreta vive en
  /// ReproductorApertura (arriba en la cadena); declaración para el watchdog.
  Future<void> _openTrack(ItemFeed track);

  /// Abre [uriPlay] en el player: headers http directos (media_kit los aplica
  /// desde un hook cuyo lookup falla con URLs googlevideo largas firmadas y
  /// mpv recibe 403 — setear la propiedad en la instancia misma), open, play,
  /// re-aplicar velocidad y fade-in suave.
  Future<void> _abrirEnPlayer(
    String uriPlay,
    ItemFeed track,
    String idNormalizado,
  ) async {
    try {
      // Serializado en la cola del player: un segundo open/stop nunca debe
      // pisar a este mientras está en vuelo (media_kit crashea con "Callback
      // invoked after it has been deleted" en el hilo mpv si dos operaciones
      // destructivas se solapan — p.ej. watchdog anti-stall re-resolviendo).
      await _enColaPlayer(() async {
        final headersYt = _headersParaUrl(uriPlay);
        try {
          await (_player.platform as dynamic).setProperty(
            'http-header-fields',
            headersYt == null || headersYt.isEmpty
                ? ''
                : headersYt.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join(','),
          );
        } catch (_) {}
        await _player.open(Media(uriPlay, httpHeaders: headersYt));
        // Audio-only: saltar cualquier pista de video para que streams que solo
        // exponen video+audio (YouTube itag=18 fallback) decodifiquen su audio
        // en vez de stallear en H.264 sin superficie de video.
        try {
          await (_player.platform as dynamic).setProperty('vid', 'no');
        } catch (_) {}
        await _player.play();
        // media_kit resetea rate a 1.0 en cada open(): re-aplicar la del usuario.
        if (state.velocidad != 1.0) {
          try {
            await _player.setRate(state.velocidad);
          } catch (_) {}
        }
      });
      // Fade-in suave en cada track nuevo (transición sin click/pop).
      unawaited(_fadeInAudio());
      // Solo una completación sin un open más nuevo en vuelo puede ser EOF
      // real; cualquier otra pertenece al media que este open descartó.
      _generacionAbiertaEn = _generacionOpen;
    } catch (e) {
      // Open falló silenciosamente — el watchdog de stall lo maneja abajo.
    }
  }

  /// Watchdog anti-stall: mpv falla los opens de streams muertos/vencidos/403
  /// SIN error visible en Dart (el media nunca produce un evento, solo nunca
  /// arranca) — el player se quedaría en 00:00 para siempre. Unos segundos
  /// tras un open de red, si la posición no avanzó, tratar la URL como muerta:
  /// invalidarla y re-resolver el MISMO track una vez por el pipeline de
  /// descarga. Archivos locales exentos; un open más nuevo supersede.
  void _vigilarStall(String uriPlay, String idNormalizado, ItemFeed track) {
    if (!uriPlay.startsWith('http://') && !uriPlay.startsWith('https://')) {
      return;
    }
    final gen = _generacionOpen;
    final watchKey = idNormalizado;
    Future<void> checkStall() async {
      if (isClosed) return;
      if (gen != _generacionOpen || gen != _generacionAbiertaEn) return;
      // Solo cuando la posición verdaderamente nunca empezó a moverse. Un
      // buffer de red lento que eventualmente entrega no debe cortarse.
      if (_player.state.position >= const Duration(seconds: 1)) return;
      await Future<void>.delayed(const Duration(seconds: 6));
      if (isClosed) return;
      if (gen != _generacionOpen || gen != _generacionAbiertaEn) return;
      if (_player.state.position >= const Duration(seconds: 1)) return;
      if (_player.state.playing == false) return;
      final reintentos = _reintentosStall[watchKey] ?? 0;
      if (reintentos >= 1) return; // un intento fresco alcanza
      _reintentosStall[watchKey] = reintentos + 1;
      debugPrint(
        '[Player] Open stalled at 00:00 for $watchKey — re-resolving fresh.',
      );
      _cacheUrlStream.remove(_claveCacheStream(watchKey));
      _urlRotaPorTrack[watchKey] = uriPlay;
      // Dejar que el re-open pase el guard de "mismo track".
      _forzarReopen = true;
      unawaited(_openTrack(track));
    }

    unawaited(Future<void>.delayed(const Duration(seconds: 8), checkStall));
  }

  /// Reporta el fallo de resolución del open con un mensaje legible según el
  /// tipo de error (verificación requerida / 429 / offline / genérico) y
  /// abre el modal de verificación del proveedor que la necesita.
  Future<void> _manejarFalloOpen(ItemFeed track) async {
    final raw = _ultimoErrorStream.trim();
    final rawLower = raw.toLowerCase();
    final necesitaVerificacion =
        _ultimoTipoErrorStream.toLowerCase() == 'verification_required' ||
        rawLower.contains('verify_required') ||
        rawLower.contains('verification required') ||
        rawLower.contains('verify required');
    String? msg;
    if (necesitaVerificacion) {
      final servicio = _ultimoServicioStream.isNotEmpty
          ? _ultimoServicioStream
          : (track.source ?? '');
      final nombre = ServicioVerificacion().nombreFuente(servicio);
      msg = nombre.isNotEmpty
          ? 'Sesión de $nombre no verificada — completa la verificación '
              'para reproducir esta canción.'
          : 'Sesión no verificada — completa la verificación para '
              'reproducir esta canción.';
      // Refrescar ya la sesión del proveedor que la necesita (p.ej. amazon
      // alcanzado durante fallback).
      unawaited(_verificarServicioParaPlayback(servicio, nombre));
    } else if (raw.contains('429') ||
        rawLower.contains('rate limit') ||
        rawLower.contains('too many')) {
      msg = 'Proveedor temporalmente saturado (429) — inténtalo de nuevo '
          'en unos segundos.';
    } else if (_ultimoTipoErrorStream.toLowerCase() == 'offline' ||
        rawLower.contains('sin conexión')) {
      msg = 'Sin conexión a internet — descarga esta canción para '
          'reproducirla sin red.';
    } else if (raw.isNotEmpty) {
      msg = 'No se pudo obtener un stream original para esta canción.';
    }
    if (msg != null) {
      emit(
        state.copiarCon(
          estadoReproduccion: EstadoReproduccion.error,
          mensajeError: msg,
        ),
      );
      if (!necesitaVerificacion) ServicioVerificacion().mostrarAviso(msg);
    }
  }
}