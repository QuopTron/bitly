// ─────────────────────────────────────────────────────────────
// descargas_poll_timeout.dart — PART de cubit_descargas.dart:
// detección de descargas colgadas: si hay items en progreso pero el
// backend no reporta nada vivo por ~18s (6 polls), se marcan
// interrumpidos (NUNCA el track que la cola FIFO espera — tiene su
// propio timeout de 90s). Además el timeout duro de 120s por item:
// solo los trackers huérfanos reciben timeout duro, extendiendo si
// Go sigue reportando 'downloading', y buscando un archivo
// reproducible en disco cuando el item desapareció del tracker.
// También limpia _borradosPendientes cuando Go confirma el cancel.
// Se conecta con: descargas_poll_lotes.dart (misma library).
// Parte del flujo: descargas (poll → timeouts).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Timeouts de descargas colgadas. Mixin aplicado en CubitDescargas.
mixin DescargasPollTimeout on DescargasPollLotes {
  /// Detección de racha vacía + timeout duro de items colgados.
  Future<void> _detectarTimeouts(Map<String, dynamic> items) async {
    // ── 3. Timeout por racha vacía ──
    // Si hay items en progreso pero sin progreso vivo del backend por ~18s
    // (6 polls), marcarlos interrumpidos — PERO nunca matar el track que la
    // cola FIFO está esperando (tiene su propio timeout y puede estar en
    // fase de decrypt).
    final hayEnProgreso = state.descargas.values
        .any((d) => d.estado == EstadoDescarga.enProgreso);
    if (hayEnProgreso && items.isEmpty) {
      _rachaProgresoVacio++;
      if (_rachaProgresoVacio >= 6) {
        final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
        var changed = false;
        for (final key in dl.keys) {
          if (dl[key]!.estado == EstadoDescarga.enProgreso) {
            // CRÍTICO: nunca matar el track que la cola FIFO espera.
            if (key == _idTrackActualCola) continue;
            dl[key] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido, progreso: 0.0);
            changed = true;
          }
        }
        if (changed) emit(state.copiarCon(descargas: dl));
        _rachaProgresoVacio = 0;
      }
    } else if (!hayEnProgreso) {
      _rachaProgresoVacio = 0;
    }

    // ── 4. Timeout duro: marcar items colgados >120s como interrumpidos ──
    // Saltar el track actual de la cola — tiene su propio timeout en
    // _procesarColaDescargas. Solo los trackers huérfanos reciben timeout duro.
    final ahora = DateTime.now();
    final hardDl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    var hardTimedOut = false;
    for (final id in _iniciadosEn.keys.toList()) {
      if (hardDl[id]?.estado != EstadoDescarga.enProgreso) {
        _iniciadosEn.remove(id);
        continue;
      }
      // Saltar el track que la cola FIFO está procesando.
      if (id == _idTrackActualCola) continue;
      if (ahora.difference(_iniciadosEn[id]!) > const Duration(seconds: 120)) {
        // Chequear el estado vivo del tracker: stateKey → raw ID de Go.
        String? liveStatus;
        for (final entry in _itemIdAKeyEstado.entries) {
          if (entry.value == id) {
            final rawItem = items[entry.key];
            if (rawItem is Map) {
              liveStatus = _estadoDe(rawItem as Map<String, dynamic>);
            }
            break;
          }
        }
        if (liveStatus == 'completed') {
          _log.i('[poll] timeout duro para $id pero Go reporta completado — marcando completado');
          hardDl[id] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
          _iniciadosEn.remove(id);
          hardTimedOut = true;
          if (!id.endsWith('_lyrics') && !id.endsWith('_video')) _senializarTrackTerminado(id);
        } else if (liveStatus == 'failed' || liveStatus == 'cancelled') {
          _log.i('[poll] timeout duro para $id pero Go reporta $liveStatus — marcando interrumpido');
          hardDl[id] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido, progreso: 0.0);
          _iniciadosEn.remove(id);
          hardTimedOut = true;
          if (!id.endsWith('_lyrics') && !id.endsWith('_video')) _senializarTrackTerminado(id);
        } else if (liveStatus == 'downloading' || liveStatus == 'preparing') {
          // Go sigue trabajando en este item — extender el timeout.
          _log.d('[poll] timeout duro para $id pero Go aún reporta $liveStatus — extendiendo');
          _iniciadosEn[id] = ahora;
        } else {
          // Item desaparecido del tracker — la descarga completó mientras el
          // poll estaba ocupado. Chequear un archivo reproducible en disco.
          final altPath = await _buscarArchivoAlternativo(id);
          if (altPath != null) {
            _log.i('[poll] timeout duro para $id pero existe archivo en disco: $altPath — marcando completado');
            hardDl[id] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
            _iniciadosEn.remove(id);
            hardTimedOut = true;
            if (!id.endsWith('_lyrics') && !id.endsWith('_video')) _senializarTrackTerminado(id);
          } else {
            _log.i('[poll] timeout duro para $id — sin tracker, sin archivo — marcando interrumpido');
            hardDl[id] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido, progreso: 0.0);
            _iniciadosEn.remove(id);
            hardTimedOut = true;
            if (!id.endsWith('_lyrics') && !id.endsWith('_video')) _senializarTrackTerminado(id);
          }
        }
      }
    }
    if (hardTimedOut) emit(state.copiarCon(descargas: hardDl));

    // Limpiar _borradosPendientes para IDs que Go ya no reporta (confirmando
    // que el RPC cancel surtió efecto). Permite futuras re-descargas.
    if (_borradosPendientes.isNotEmpty) {
      if (items.isNotEmpty) {
        final liveIds = items.keys.toSet();
        _borradosPendientes.removeWhere((id) => !liveIds.contains(id));
      } else {
        // Go no reporta nada → todos los cancels surtieron efecto.
        _borradosPendientes.clear();
      }
    }
  }
}