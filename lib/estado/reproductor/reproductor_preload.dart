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
mixin ReproductorPreload on ReproductorPreloadVecinos {
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


}