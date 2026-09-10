// ─────────────────────────────────────────────────────────────
// reproductor_stream_resolve.dart — PART de cubit_reproductor.dart:
// resolución de la URL de stream con caché en memoria + persistente:
// reuso de resultados de preload, probe de vida de URLs cacheadas,
// deduplicación de resoluciones concurrentes y reuso de la URL probe
// como plan B cuando el respaldo de descarga no produjo copia.
// Se conecta con: reproductor_stream_pipeline.dart (misma library).
// Parte del flujo: reproducción (resolver URL de streaming).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Resolución de URL de stream. Mixin aplicado en CubitReproductor.
mixin ReproductorStreamResolve on ReproductorStreamPipeline {
  /// Guarda el caché persistente de URLs — implementación concreta en
  /// ReproductorInit (arriba en la cadena); declaración para el fire-and-forget.
  Future<void> _guardarCachePersistente();

  /// Resuelve la URL de stream de [track] vía el backend Go, cacheando el
  /// resultado y deduplicando resoluciones concurrentes.
  /// [conRespaldo] deja que un prefetch de fondo pida el pipeline COMPLETO
  /// (respaldo de descarga incluido) en vez del probe directo barato — se usa
  /// para exactamente un track (el siguiente inmediato en WiFi) para que
  /// avanzar la cola arranque al instante incluso en proveedores DRM/preview.
  @override
  Future<String?> _resolveStreamUrl(
    ItemFeed track, {
    bool esPreload = false,
    bool conRespaldo = false,
  }) async {
    final normKey = normalizarId(track.id);
    final key = _claveCacheStream(normKey);
    // Una resolución con respaldo completo (tap real O preload completo) puede
    // reusar cualquier resultado cacheado que vino con respaldo. Un preload
    // plano puede reusar cualquier URL cacheada.
    final quiereRespaldo = !esPreload || conRespaldo;
    final cacheado = _cacheUrlStream[key];
    // Un preload puede reusar cualquier URL cacheada. Un tap real reusa un
    // resultado cacheado cuando vino del pipeline de descarga (file://,
    // conRespaldo) O cuando el preload resolvió un http(s) directo de una
    // fuente de stream completo. Un stream que ya falló fuerza re-resolución.
    if (cacheado != null &&
        !_urlStreamVieja(cacheado) &&
        (esPreload ||
            cacheado.conRespaldo ||
            (_puedeReusarPreloadDirecto(track, cacheado.url) &&
                _urlRotaPorTrack[normKey] != cacheado.url))) {
      // Un tap REAL a punto de reusar una URL cacheada debe asegurarse de que
      // la URL sigue sirviendo (las URLs cacheadas se pudren silenciosamente y
      // mpv falla esos opens sin error). Los preloads saltan el probe.
      if (esPreload || await _urlStreamViva(cacheado.url)) {
        return cacheado.url;
      }
      debugPrint('[Player] Cached stream dead — re-resolving $normKey');
      _cacheUrlStream.remove(key);
      _urlRotaPorTrack[normKey] = cacheado.url;
    }
    final enVuelo = _futuresStream[key];
    if (enVuelo != null) {
      // Una resolución probe-only está en vuelo pero el llamador quiere el
      // pipeline completo — arrancar una resolución fresca CON respaldo.
      if (quiereRespaldo && !enVuelo.$2) {
        _futuresStream.remove(key);
      } else {
        return enVuelo.$1;
      }
    }

    final future =
        _resolveStreamUrlInner(track, esPreload: esPreload, conRespaldo: conRespaldo);
    _futuresStream[key] = (future, quiereRespaldo);
    try {
      final url = await future;
      if (url != null && url.isNotEmpty) {
        // Nunca dejar que un preload que termina tarde degrade una entrada
        // mejor que un tap ya guardó.
        final actual = _cacheUrlStream[key];
        if (actual == null || !esPreload || !actual.conRespaldo) {
          _cacheUrlStream[key] =
              _StreamCacheado(url, quiereRespaldo, _expiryParaUrl(url));
        }
        _marcarListo(normKey);
        unawaited(_guardarCachePersistente());
        return url;
      }
      // Un tap real que no pudo producir una copia de calidad de descarga
      // todavía tiene la URL de stream directo del preload como plan B.
      if (!esPreload && cacheado != null && !cacheado.conRespaldo) {
        if (_urlRotaPorTrack[normKey] != cacheado.url) return cacheado.url;
      }
      return url;
    } finally {
      // Solo remover nuestra propia entrada: un tap concurrente pudo
      // reemplazarla con una resolución fresca.
      final actual = _futuresStream[key];
      if (actual != null && identical(actual.$1, future)) {
        _futuresStream.remove(key);
      }
    }
  }
}