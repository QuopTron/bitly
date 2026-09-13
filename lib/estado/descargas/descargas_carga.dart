// ─────────────────────────────────────────────────────────────
// descargas_carga.dart — PART de cubit_descargas.dart: inicialización
// del cubit: carga del userId y del historial de descargas (tracks +
// lotes) al estado, merge sin pisar items en progreso, y el arranque
// del polling + refresh + reparación de arranque. La carga de tracks
// individuales y de lotes vive en descargas_carga_tracks.dart y
// descargas_carga_lotes.dart (se declaran abstract aquí).
// Se conecta con: descargas_carga_lotes.dart (misma library).
// Parte del flujo: descargas (arranque y refresh de historial).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Inicialización y orquestación de carga. Mixin aplicado en CubitDescargas.
/// _cargarHistorialTracks y _cargarHistorialLotes vienen implementados en
/// DescargasCargaTracks / DescargasCargaLotes (super-mixins en la cadena).
mixin DescargasCarga on DescargasCargaLotes {
  Future<void> initialize() async {
    emit(state.copiarCon(cargando: true));
    try {
      await _cargarUserId();
      await _cargarHistorial();
    } catch (_) {}
    emit(state.copiarCon(cargando: false));
    _empezarPolling();
    _empezarRefreshHistorial();
    // Reparación única de arranque: detecta descargas que no son audio
    // reproducible (encriptadas guardadas antes del fix de decrypt) y las
    // re-descarga automáticamente. Corre async para no bloquear la home.
    unawaited(_repararDescargasRotas());
  }

  /// Calienta la caché de ajustes del usuario (el username no se usa más).
  Future<void> _cargarUserId() async {
    try {
      await di.sl<CacheAjustes>().cargarDatosSetup();
    } catch (_) {}
  }

  /// Carga [getHistorialDescargas] y [getLotesDescargados] al estado.
  ///
  /// En lugar de capturar un snapshot de [state.descargas] al inicio (lo que
  /// causa race conditions con _pollProgreso), construye un map de items
  /// completados desde el historial y los mergea en el estado actual justo
  /// antes de emitir. Esto evita perder actualizaciones concurrentes.
  @override
  Future<void> _cargarHistorial() async {
    final fps = Set<String>.from(state.huellasDescargadas);
    // El primer elemento de la tupla de tracks es el set de fingerprints
    // internos de la implementación; el merge usa el fps capturado acá.
    final (_, completadosTracks, cambiadoTracks) = await _cargarHistorialTracks();
    final (completadosLotes, cambiadoLotes) = await _cargarHistorialLotes();

    final completados = <String, DatosEstadoDescarga>{}
      ..addAll(completadosTracks)
      ..addAll(completadosLotes);
    final cambiado = cambiadoTracks || cambiadoLotes;

    if (cambiado || fps.length != state.huellasDescargadas.length) {
      // Mergear los items completados en el estado ACTUAL para no perder
      // items in-progress agregados concurrentemente por _pollProgreso().
      // No pisar items en progreso — reflejan una descarga activa.
      final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
      for (final entry in completados.entries) {
        final existente = dl[entry.key];
        if (existente?.estado == EstadoDescarga.enProgreso) continue;
        if (existente?.estado != EstadoDescarga.completado) {
          dl[entry.key] = entry.value;
        }
      }
      emit(state.copiarCon(descargas: dl, huellasDescargadas: fps));
    }
  }
}