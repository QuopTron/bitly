// ─────────────────────────────────────────────────────────────
// reproductor_preload_media.dart — PART de cubit_reproductor.dart:
// precarga de los media del track actual: letras (LRC) vía el
// backend y video de fondo (local → visualizador directo → descarga
// a temp), más la entrada pública de letras bajo demanda del player
// grande.
// Se conecta con: reproductor_preload.dart (misma library).
// Parte del flujo: player grande (letras + canvas de video).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Precarga de media del track actual. Mixin aplicado en CubitReproductor.
mixin ReproductorPreloadMedia on ReproductorPreload {
  /// Precarga las letras (LRC) de [track] vía el backend Go.
  Future<String?> _preloadLetras(ItemFeed track) async {
    if (!_letrasHabilitadas ||
        track.name.isEmpty ||
        (track.artists ?? '').isEmpty) {
      return null;
    }
    precargandoLetras = true;
    try {
      final resultado = await di.sl<BackendService>().rpcCall(
        'getLyricsLRCWithSource',
        {
          'track_name': track.name,
          'artist_name': track.artists ?? '',
          'duration_ms': 0,
        },
      );
      final data = _decodeRpcResult(resultado);
      if (data != null) {
        final letras = data['lyrics'] as String? ?? '';
        final instrumental = data['instrumental'] == true;
        letrasPrecargadas = (!instrumental && letras.isNotEmpty) ? letras : null;
      } else {
        letrasPrecargadas = null;
      }
    } catch (_) {
      letrasPrecargadas = null;
    }
    precargandoLetras = false;
    return letrasPrecargadas;
  }

  /// Precarga el video de fondo de [track]: local primero, luego la URL
  /// directa de visualizador (progresiva, ~1-2s) y por último la descarga
  /// completa a temp.
  Future<void> _preloadVideo(ItemFeed track) async {
    if (!_videoHabilitado) return;
    precargandoVideo = true;
    try {
      String? videoUrl = _resolveLocalVideoUrl(track);
      videoUrl ??= await resolverUrlVisualizador(track);
      videoUrl ??= await descargarVideoATemp(track);
      urlVideoPrecargado = videoUrl;
      videoPrecargadoListo.value = videoUrl;
    } catch (_) {
      urlVideoPrecargado = null;
      videoPrecargadoListo.value = null;
    }
    precargandoVideo = false;
  }

  /// Entrada pública del toggle de letras del player grande: busca las LRC
  /// bajo demanda cuando la precarga falló o se saltó. Devuelve las letras
  /// (o null cuando no hay / está deshabilitado).
  Future<String?> obtenerLetrasBajoDemanda(ItemFeed track) async {
    if (!_letrasHabilitadas ||
        track.name.isEmpty ||
        (track.artists ?? '').isEmpty) {
      return null;
    }
    if (letrasPrecargadas != null && letrasPrecargadas!.isNotEmpty) {
      return letrasPrecargadas;
    }
    return _preloadLetras(track);
  }
}