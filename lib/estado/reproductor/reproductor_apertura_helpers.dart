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
mixin ReproductorAperturaHelpers on ReproductorFalloOpen {
  /// Reapertura de un track — la implementación concreta vive en
  /// ReproductorApertura (arriba en la cadena); declaración para el watchdog.
  Future<void> _openTrack(ItemFeed track);

  /// Abre [uriPlay] en el player: headers http directos (en mpv se aplican
  /// como propiedad en la instancia misma, porque el hook de media_kit falla
  /// con URLs googlevideo largas firmadas y mpv recibe 403), open, play,
  /// re-aplicar velocidad y fade-in suave. En web las cabeceras y las
  /// propiedades son no-ops: el navegador no puede mandarlas.
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
        await _player.propiedad(
          'http-header-fields',
          headersYt == null || headersYt.isEmpty
              ? ''
              : headersYt.entries.map((e) => '${e.key}: ${e.value}').join(','),
        );
        await _player.abrir(uriPlay, headers: headersYt);
        // Audio-only: saltar cualquier pista de video para que streams que solo
        // exponen video+audio (YouTube itag=18 fallback) decodifiquen su audio
        // en vez de stallear en H.264 sin superficie de video.
        await _player.propiedad('vid', 'no');
        await _player.reproducir();
        // El motor resetea la velocidad a 1.0 en cada open(): re-aplicar la
        // del usuario.
        if (state.velocidad != 1.0) {
          await _player.ponerVelocidad(state.velocidad);
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
      if (_player.posicion >= const Duration(seconds: 1)) return;
      await Future<void>.delayed(const Duration(seconds: 6));
      if (isClosed) return;
      if (gen != _generacionOpen || gen != _generacionAbiertaEn) return;
      if (_player.posicion >= const Duration(seconds: 1)) return;
      if (_player.reproduciendo == false) return;
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


}
