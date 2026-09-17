// ─────────────────────────────────────────────────────────────
// descargas_cola_track.dart — PART de cubit_descargas.dart:
// procesamiento de UN track de la cola secuencial. Marca el track y
// su lote en progreso, despacha audio/video/letras, espera la señal
// de fin (timeout de 90s), mira el disco por si el poll todavía no
// propagó, y verifica que haya quedado un archivo reproducible.
// Devuelve si el track quedó bien; el avance del FIFO lo decide
// descargas_cola.dart.
// Se conecta con: descargas_cola.dart (misma library).
// Parte del flujo: descargas (cola secuencial).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Procesamiento de un track. Mixin aplicado en CubitDescargas.
mixin DescargasColaTrack on DescargasCola {
  /// Procesa UN track en una pasada. Devuelve true si quedó con un archivo
  /// reproducible en disco (o ya completado en la BD).
  @override
  Future<bool> _procesarTrackDeCola(_TrackEnCola track, String baseId) async {
    _completadorTrackActual = Completer<void>();
    _idTrackActualCola = baseId;
    // Recordar los datos del intento: el aviso de descarga puede volver a
    // lanzar esta misma canción después de un fallo definitivo.
    _trackMapPorBaseId[baseId] = track.trackMap;
    // Cada track arranca sin el veredicto del anterior: quién lo corta (poll,
    // gate, timeout) es quién decide si el reintento en sitio corresponde.
    _falloReintentable = false;

    _log.i('[cola] ▶ START track=$baseId titulo="${track.trackMap['track_title']}" '
        'cola_restante=${_colaDescargas.length}');

    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    dl[baseId] = const DatosEstadoDescarga(estado: EstadoDescarga.enProgreso, progreso: 0.0);
    // Marcar el lote al que pertenece este track como en progreso.
    final bk = track.batchKey;
    if (bk != null) {
      dl[bk] = const DatosEstadoDescarga(estado: EstadoDescarga.enProgreso, progreso: 0.0);
    }
    emit(state.copiarCon(descargas: dl));

    _despacharTrackLote(track.trackMap, track.trackId, track.source, track.ajustes,
        calidadForzada: track.calidadForzada);

    try {
      await _completadorTrackActual!.future.timeout(const Duration(seconds: 90));
    } catch (_) {
      _log.w('[cola] ⏰ TIMEOUT para $baseId tras 90s — evaluando lo que haya en disco');
      // NO cancelar el tracker de Go — la descarga puede seguir corriendo;
      // el poll detectará la completación después y la marcará completada.
    }

    // Ceder para que el emit de _pollProgreso propague el estado
    // (completado/interrumpido) antes de leerlo acá abajo.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // ── Si sigue enProgreso tras la señal, chequear el disco directo ──
    // El finalize de Go puede disparar _senializarTrackTerminado antes de
    // que el poll de Dart procese la completación.
    if (state.descargas[baseId]?.estado == EstadoDescarga.enProgreso) {
      final altFile = await _buscarArchivoAlternativo(baseId, '');
      if (altFile != null && altFile.isNotEmpty) {
        _log.i('[cola] $baseId: archivo en disco tras la señal: $altFile — marcando completado');
        final tdl = Map<String, DatosEstadoDescarga>.from(state.descargas);
        tdl[baseId] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
        emit(state.copiarCon(descargas: tdl));
      }
    }

    final estadoActual = state.descargas[baseId]?.estado;

    // ── Verificar que la descarga realmente produjo un archivo ──
    if (estadoActual == EstadoDescarga.completado) {
      var fileOk = await _verificarArchivoDescargado(baseId);
      // Esperar un poco por otros proveedores (Apple Music .m4a).
      for (var intento = 1; intento <= 3 && !fileOk; intento++) {
        _log.i('[cola] $baseId: verificación intento $intento — esperando 3s...');
        await Future<void>.delayed(const Duration(seconds: 3));
        if (state.descargas[baseId]?.estado == EstadoDescarga.completado) {
          fileOk = await _verificarArchivoDescargado(baseId);
        }
      }
      if (fileOk) {
        _colaRedescarga.remove(baseId);
        _log.i('[cola] ✔ DONE track=$baseId');
        return true;
      }
      _marcarInterrumpido(baseId, 'La descarga no dejó un archivo reproducible');
      _log.w('[cola] ⚠ archivo faltante/corrupto para $baseId');
      return false;
    }

    if (estadoActual == EstadoDescarga.enProgreso) {
      // Track sigue en progreso (Go no reportó fin, p.ej. timeout).
      // Una última oportunidad — el poll puede haber persistido el archivo.
      await Future<void>.delayed(const Duration(seconds: 3));
      if (state.descargas[baseId]?.estado == EstadoDescarga.completado) {
        final fileOk = await _verificarArchivoDescargado(baseId);
        if (fileOk) {
          _colaRedescarga.remove(baseId);
          _log.i('[cola] ✔ DONE track=$baseId (tras espera extra)');
          return true;
        }
      }
      _marcarInterrumpido(baseId, 'El backend no reportó el fin de la descarga');
      _log.w('[cola] ⚠ $baseId sin fin reportado por el backend');
      return false;
    }

    // Interrumpido/ninguno: quién lo marcó ya dejó su veredicto en
    // _falloReintentable (el poll lo calcula del motivo; el gate del plan free
    // y la carpeta inaccesible lo ponen en false porque necesitan al usuario).
    // Antes se forzaba false acá y ningún fallo de proveedor se reintentaba.
    _log.i('[cola] ⏹ track=$baseId cortado con estado=$estadoActual '
        '(reintentable=$_falloReintentable)');
    return false;
  }
}
