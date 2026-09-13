// ─────────────────────────────────────────────────────────────
// descargas_cola.dart — PART de cubit_descargas.dart: la cola
// secuencial de descargas con consciencia de lote. Procesa UN track
// a la vez (FIFO estricto): marca el track y su lote en progreso,
// despacha el audio/video/letras, espera la señal de fin (con
// timeout de 90s), y ANTES de avanzar verifica que la descarga
// anterior haya producido un archivo reproducible en disco. Un
// archivo faltante/corrupto marca el track interrumpido y avanza
// (el reintento automático de lote lo retoma al terminar el álbum).
// Se conecta con: descargas_reintentar.dart (misma library).
// Parte del flujo: descargas (cola secuencial).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Procesador de la cola secuencial. Mixin aplicado en CubitDescargas.
mixin DescargasCola on DescargasReintentar {
  /// Despacho de un track dentro de un lote — implementación concreta en
  /// DescargasTrack (arriba en la cadena).
  void _despacharTrackLote(
    Map<String, dynamic> trackMap,
    String trackId,
    String source,
    AjustesDescarga ajustes, {
    String? calidadForzada,
  });

  /// Procesa la cola global un track a la vez. Los lotes se procesan en FIFO:
  /// primero todos los tracks del lote 1, luego los del lote 2, etc.
  @override
  Future<void> _procesarColaDescargas() async {
    if (_procesandoCola || _colaDescargas.isEmpty) return;
    _procesandoCola = true;

    while (_colaDescargas.isNotEmpty) {
      final track = _colaDescargas.removeAt(0);
      _completadorTrackActual = Completer<void>();

      final normalizedId = normalizarId(track.trackId);
      final baseId = 'track_${normalizedId}_${track.source}';
      _idTrackActualCola = baseId;

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
        _log.w('[cola] ⏰ TIMEOUT para $baseId tras 90s — pasando al siguiente track');
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

      // ── Verificar que la descarga realmente produjo un archivo ──
      final estadoActual = state.descargas[baseId]?.estado;
      if (estadoActual == EstadoDescarga.completado) {
        var fileOk = await _verificarArchivoDescargado(baseId);
        if (fileOk) {
          _colaRedescarga.remove(baseId);
        } else {
          // Esperar un poco por otros proveedores (Apple Music .m4a).
          for (var intento = 1; intento <= 3 && !fileOk; intento++) {
            _log.i('[cola] $baseId: verificación intento $intento — esperando 3s...');
            await Future<void>.delayed(const Duration(seconds: 3));
            final recheckDl = state.descargas[baseId]?.estado;
            if (recheckDl == EstadoDescarga.completado) {
              fileOk = await _verificarArchivoDescargado(baseId);
            }
          }
          if (!fileOk) {
            // NO re-despachar aquí — rompería el FIFO iniciando una descarga
            // concurrente. Marcar interrumpido; el reintento automático del
            // lote lo retoma al terminar el álbum.
            _log.w('[cola] ⚠ archivo faltante/corrupto para $baseId — marcando interrumpido');
            final tdl = Map<String, DatosEstadoDescarga>.from(state.descargas);
            tdl[baseId] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido, progreso: 0.0);
            emit(state.copiarCon(descargas: tdl));
          }
        }
      } else if (estadoActual == EstadoDescarga.enProgreso) {
        // Track sigue en progreso (Go no reportó fin, p.ej. timeout).
        // Una última oportunidad — el poll puede haber persistido el archivo.
        await Future<void>.delayed(const Duration(seconds: 3));
        final chequeoFinal = state.descargas[baseId]?.estado;
        if (chequeoFinal == EstadoDescarga.completado) {
          final fileOk = await _verificarArchivoDescargado(baseId);
          if (fileOk) _colaRedescarga.remove(baseId);
        }
      }

      _log.i('[cola] ✔ DONE track=$baseId resultado=${state.descargas[baseId]?.estado}');
    }

    _idTrackActualCola = null;
    _procesandoCola = false;
    _log.i('[cola] ═══ COLA VACÍA ═══');
  }
}