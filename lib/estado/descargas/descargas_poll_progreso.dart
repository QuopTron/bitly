// ─────────────────────────────────────────────────────────────
// descargas_poll_progreso.dart — PART de cubit_descargas.dart:
// el poll de progreso completo (3s): obtiene el progreso real del
// backend Go, detecta items con 'verification_required' (marca SOLO
// ese track interrumpido, señala a la cola y dispara el flujo de
// verificación WebView), procesa cada item por status, recalcula el
// progreso agregado de lotes, mergea los cambios en el estado ACTUAL
// (sin pisar modificaciones de la cola durante awaits async) y corre
// la detección de timeouts. Guarda contra polls superpuestos y
// contra el decrypt lento que excede el intervalo de 3s.
// Se conecta con: descargas_poll_timeout.dart (misma library).
// Parte del flujo: descargas (poll de progreso → Go).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Poll de progreso completo. Mixin aplicado en CubitDescargas.
mixin DescargasPollProgreso on DescargasPollTimeout {
  /// Obtiene el progreso de Go y actualiza el estado de descargas.
  @override
  Future<void> _pollProgreso() async {
    if (_verificacionEnCurso || _pollingEnCurso) return;
    _pollingEnCurso = true;

    try {
      // ── 1. Progreso en tiempo real del backend ──
      final json = await _backend.getAllDownloadProgress();
      final data = json.isNotEmpty ? jsonDecode(json) : null;
      final rawItems = (data is Map) ? data['items'] : null;
      final items = (rawItems is Map<String, dynamic>) ? rawItems : <String, dynamic>{};

      // ── 0. Chequear si algún item necesita verificación ──
      if (items.isNotEmpty) {
        for (final entry in items.entries) {
          if (entry.value is! Map) continue;
          final p = entry.value as Map<String, dynamic>;
          final status = _estadoDe(p);
          if (status == 'verification_required') {
            _log.i('[_pollProgreso] Detectado verification_required para ${entry.key}');
            // Marcar SOLO el track que necesita verificación como interrumpido,
            // no TODOS los en progreso — otros tracks pueden seguir
            // descargando exitosamente y no deben ser afectados.
            final rawId = entry.key.toString();
            final stateKey = _itemIdAKeyEstado[rawId] ?? rawId;
            final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
            if (dl[stateKey]?.estado == EstadoDescarga.enProgreso) {
              dl[stateKey] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido, progreso: 0.0);
              emit(state.copiarCon(descargas: dl));
            }
            // Señalar a la cola para que no se bloquee en un track pegado.
            if (!stateKey.endsWith('_lyrics') && !stateKey.endsWith('_video')) {
              _senializarTrackTerminado(stateKey);
            }
            _timerProgreso?.cancel();
            _verificacionEnCurso = true;
            _manejarVerificacionRequerida().then((_) {
              _verificacionEnCurso = false;
              _empezarPolling();
            });
            return;
          }
        }
      }

      final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
      // Snapshot antes de procesar — para detectar modificaciones de la cola
      // durante awaits de decrypt u otros gaps async dentro de este ciclo.
      final initialPollDl = Map<String, DatosEstadoDescarga>.from(dl);
      final fps = Set<String>.from(state.huellasDescargadas);
      bool changed = false;

      if (items.isNotEmpty) {
        _rachaProgresoVacio = 0;
        for (final entry in items.entries) {
          final rawId = entry.key.toString();
          // Traducir el item_id de Go al state key local.
          final stateKey = _itemIdAKeyEstado[rawId] ?? rawId;
          if (entry.value is! Map) continue;
          final p = entry.value as Map<String, dynamic>;
          if (await _procesarItemPoll(rawId, stateKey, p, dl, fps)) {
            changed = true;
          }
        }
      }

      // ── 2. Recalcular el progreso agregado de lotes (álbum/playlist) ──
      if (await _recalcularLotes(dl)) changed = true;

      if (changed) {
        // Mergear los cambios del poll en el estado ACTUAL para no sobreescribir
        // estados modificados por _procesarColaDescargas durante gaps async
        // (p.ej. await de decrypt). Solo aplicar nuestro cambio cuando la key
        // no fue tocada desde el snapshot del inicio del poll.
        final currentDl = Map<String, DatosEstadoDescarga>.from(state.descargas);
        for (final entry in dl.entries) {
          final current = currentDl[entry.key];
          final initial = initialPollDl[entry.key];
          if (initial == null || current == null || current.estado == initial.estado) {
            currentDl[entry.key] = entry.value;
          }
        }
        emit(state.copiarCon(
          descargas: currentDl,
          huellasDescargadas: fps,
          errorDesencriptado: _errorDesencriptadoPendiente,
        ));
        _errorDesencriptadoPendiente = null;
        _ajustarTasaRefreshHistorial();
      }

      // ── 3 y 4. Timeouts (racha vacía + timeout duro) ──
      await _detectarTimeouts(items);
    } catch (_) {
    } finally {
      _pollingEnCurso = false;
    }
  }
}