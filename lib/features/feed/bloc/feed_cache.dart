// ─────────────────────────────────────────────────────────────
// feed_cache.dart — PART de feed_bloc.dart: carga del feed en 3
// pasos — (1) restaura el último feed cacheado para mostrar
// contenido al instante (recuperación offline), (2) refresca desde
// el backend sin vaciar lo visible, y (3) persiste el feed exitoso
// para la próxima recuperación. En fallo conserva el cache.
// Se conecta con: feed_bloc.dart (misma library) + CacheFeed +
// CacheAjustes (username) + backend Go (getHomeFeed).
// Parte del flujo: feed de inicio (carga del BlocFeed).
// ─────────────────────────────────────────────────────────────

part of 'feed_bloc.dart';

/// Carga el feed: cache primero, refresh en background después.
Future<void> _cargarFeed(
  BlocFeed bloc,
  CargarFeed event,
  Emitter<EstadoFeed> emit,
) async {
  final cache = sl<CacheFeed>();
  final setup = await sl<CacheAjustes>().cargarDatosSetup();

  // 1. Restaurar el último feed conocido al instante (offline recovery).
  DatosCacheFeed? cacheado;
  try {
    cacheado = await cache.cargar();
  } catch (_) {
    cacheado = null;
  }

  if (cacheado != null && cacheado.secciones.isNotEmpty) {
    emit(
      bloc.state.copiarCon(
        secciones: cacheado.secciones,
        usuario: setup?.username ?? bloc.state.usuario,
        fuenteSeleccionada: bloc._fuenteValida(
          cacheado.secciones,
          cacheado.fuenteSeleccionada,
        ),
        cargando: false,
      ),
    );
  } else {
    emit(bloc.state.copiarCon(cargando: true));
  }

  // 2. Refrescar desde el backend en background, sin vaciar lo visible.
  try {
    final secciones = await bloc._backend.getHomeFeed();
    if (emit.isDone) return;
    final valida = bloc._fuenteValida(secciones, bloc.state.fuenteSeleccionada);
    emit(
      bloc.state.copiarCon(
        secciones: secciones,
        usuario: setup?.username ?? '',
        fuenteSeleccionada: valida,
        cargando: false,
      ),
    );
    // 3. Persistir el feed exitoso para la próxima recuperación.
    await cache.guardar(secciones, valida);
  } catch (e) {
    if (emit.isDone) return;
    // 4. En fallo se conserva lo restaurado: el estado no guarda texto, así
    // que el motivo solo queda en el log.
    debugPrint('[feed] refresco del feed falló: $e');
    emit(bloc.state.copiarCon(cargando: false));
  }
}
