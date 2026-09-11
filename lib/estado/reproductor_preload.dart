// ─────────────────────────────────────────────────────────────
// reproductor_preload.dart — PART de cubit_reproductor.dart:
// precarga de contexto y vecinos de la cola: resuelve streams de
// tracks próximos en segundo plano, el preload completo del siguiente
// inmediato (cualquier red, para eliminar el gap del crossfade) y
// candidatos aleatorios en shuffle. Las letras/video del track actual
// viven en reproductor_preload_media.dart.
// El tope de vecinos es ADAPTATIVO: sale del perfil de rendimiento y se
// recorta según la calidad de red medida (ServicioCalidadRed), de modo
// que una red excelente precarga más y una red lenta no malgasta datos.
// Se conecta con: reproductor_video_fondo.dart (misma library) +
// servicio_calidad_red (nivel medido).
// Parte del flujo: reproducción (prefetch de fondo).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Precarga de contexto/vecinos. Mixin aplicado en CubitReproductor.
mixin ReproductorPreload on ReproductorVideoFondo {
  /// Tope de vecinos a precargar según la calidad de red medida.
  ///
  /// - **Excelente**: se respeta el valor del perfil, incluso en datos
  ///   móviles (la red sobra y el usuario gana fluidez).
  /// - **Buena / sin dato todavía**: completo en red fija; en móvil se
  ///   recorta a 2 para no gastar megas de más.
  /// - **Regular**: solo 1 vecino, y únicamente en red fija.
  /// - **Lenta**: 0 — nada especulativo (el siguiente inmediato sigue
  ///   resolviéndose aparte, porque eso no es especulativo).
  int _topePrecargaAdaptativo(int configurado) {
    if (configurado < 1) return 0;
    final calidad = ServicioCalidadRed.instancia;
    switch (calidad.estado.value.nivel) {
      case NivelRed.excelente:
        return configurado;
      case NivelRed.buena:
      case NivelRed.desconocido:
        return calidad.redFija
            ? configurado
            : (configurado > 2 ? 2 : configurado);
      case NivelRed.regular:
        return calidad.redFija ? 1 : 0;
      case NivelRed.mala:
        return 0;
    }
  }

  /// Pre-resuelve streams de los tracks visibles de [tracks] hasta [limit],
  /// solo en WiFi y según el perfil. Un feed recién cargado disparar 10+
  /// resoluciones saturaría el bridge del backend mientras el usuario busca.
  Future<void> precachearContexto(List<ItemFeed> tracks, {int? limit}) async {
    final perfil = di.sl<ValueNotifier<PerfilRendimiento>>().value;
    if (!perfil.precargaHabilitada) return;
    final tope = _topePrecargaAdaptativo(limit ?? perfil.precargaTracks);
    if (tope < 1) return;
    var agregados = 0;
    for (final track in tracks) {
      if (agregados >= tope) break;
      if (track.type != 'track') continue;
      if (track.name.trim().isEmpty) continue;
      if (_cacheUrlStream.containsKey(_claveCacheStream(normalizarId(track.id)))) {
        continue;
      }
      if (_resolveLocalUri(track) != null) continue;
      _programarPrefetch(track);
      agregados++;
    }
  }

  /// Pre-resuelve URLs de stream de tracks próximos y anteriores de la cola
  /// para que siguiente/anterior sea instantáneo. Con shuffle precarga
  /// candidatos aleatorios (solo WiFi); secuencial, vecinos en orden. El
  /// siguiente inmediato corre el pipeline COMPLETO en cualquier red.
  Future<void> _preloadVecinos() async {
    final perfil = di.sl<ValueNotifier<PerfilRendimiento>>().value;
    if (!perfil.precargaHabilitada) return;
    final estado = _queueCubit.state;
    if (!estado.tieneActual) return;

    final claveActual = normalizarId(estado.actual!.id);
    final aPrecargar = <ItemFeed>{};
    // Tope adaptativo: en red excelente mantiene el perfil completo, en
    // red regular/lenta se recorta (o se apaga) para no gastar datos.
    final n = _topePrecargaAdaptativo(perfil.precargaTracks);

    if (estado.shuffle && estado.tracks.length > 1) {
      // Shuffle: siguiente/anterior eligen tracks ALEATORIOS, así que
      // precargar vecinos secuenciales es trabajo perdido. Precargar algunos
      // candidatos aleatorios para que el que suene tenga más chance de estar
      // resuelto. Especulativo = baja prioridad: lo decide la calidad.
      if (n > 0) {
        var elegidos = 0;
        var guardia = 0;
        while (elegidos < n && guardia < estado.tracks.length * 4) {
          guardia++;
          final track = estado.tracks[Random().nextInt(estado.tracks.length)];
          if (normalizarId(track.id) == claveActual) continue;
          if (aPrecargar.add(track)) elegidos++;
        }
      }
    } else if (n > 0) {
      // Secuencial: precargar los próximos y anteriores en orden de cola.
      for (int i = 1; i <= n; i++) {
        final idx = estado.indiceActual + i;
        if (idx >= estado.tracks.length) break;
        aPrecargar.add(estado.tracks[idx]);
      }
      for (int i = 1; i <= n; i++) {
        final idx = estado.indiceActual - i;
        if (idx < 0) break;
        aPrecargar.add(estado.tracks[idx]);
      }
    }

    for (final track in aPrecargar) {
      final normId = normalizarId(track.id);
      if (normId == claveActual) continue;
      if (_cacheUrlStream.containsKey(_claveCacheStream(normId))) continue;
      if (_resolveLocalUri(track) != null) continue;
      _programarPrefetch(track);
    }

    // Preload completo del siguiente inmediato: la escucha secuencial lo
    // reproducirá con casi certeza, así que se resuelve por el pipeline
    // completo (respaldo de descarga incluido) en CUALQUIER red para que el
    // gap de silencio entre tracks desaparezca. Si el probe barato ya produjo
    // un stream directo usable, esta resolución solo lo reusa.
    if (!estado.shuffle && estado.tracks.isNotEmpty) {
      final siguienteIdx = estado.indiceActual + 1;
      if (siguienteIdx < estado.tracks.length) {
        final siguiente = estado.tracks[siguienteIdx];
        final normId = normalizarId(siguiente.id);
        if (normId != claveActual && _resolveLocalUri(siguiente) == null) {
          final cacheado = _cacheUrlStream[_claveCacheStream(normId)];
          if (cacheado == null ||
              !cacheado.conRespaldo ||
              _urlStreamVieja(cacheado)) {
            _programarPrefetch(siguiente, conRespaldo: true);
          }
        }
      }
    }
  }

  /// Al empezar el fade-out del crossfade, lanza YA la resolución completa
  /// del siguiente track para que esté listo al completar el actual. Corre
  /// en cualquier red porque el crossfade ya está ocurriendo — unos KB/s de
  /// tráfico de resolución valen eliminar el gap de silencio.
  void _eagerPreloadNext() {
    final estado = _queueCubit.state;
    if (!estado.tieneActual || estado.shuffle) return;
    final siguienteIdx = estado.indiceActual + 1;
    if (siguienteIdx >= estado.tracks.length) return;
    final siguiente = estado.tracks[siguienteIdx];
    final normId = normalizarId(siguiente.id);
    final claveActual = normalizarId(estado.actual!.id);
    if (normId == claveActual) return;
    if (_resolveLocalUri(siguiente) != null) return; // ya local
    final cacheado = _cacheUrlStream[_claveCacheStream(normId)];
    if (cacheado != null && cacheado.conRespaldo && !_urlStreamVieja(cacheado)) {
      return; // ya resuelto
    }
    _programarPrefetch(siguiente, conRespaldo: true);
  }
}