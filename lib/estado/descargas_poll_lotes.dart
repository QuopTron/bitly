// ─────────────────────────────────────────────────────────────
// descargas_poll_lotes.dart — PART de cubit_descargas.dart:
// recálculo del progreso agregado de lotes (álbum/playlist) desde
// los estados individuales de sus tracks: todo completado → lote
// completado y persistido; incompleto → se mantiene vivo para que
// completar los rezagados más tarde pueda elevarlo, con auto-retry
// retrasado (15s) hasta [_maxReintentosAutoLote] veces para que el
// lote quede verde sin intervención manual. Los lotes ya completados
// se saltan (tracks compartidos re-descargados por otra playlist no
// deben degradar el estado).
// Se conecta con: descargas_poll_item.dart (misma library).
// Parte del flujo: descargas (poll → progreso de lotes).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Recálculo de progreso de lotes. Mixin aplicado en CubitDescargas.
mixin DescargasPollLotes on DescargasPollItem {
  /// Recalcula el progreso agregado de todos los lotes en [_batchTrackIds].
  /// Devuelve true si cambió el estado de algún lote.
  Future<bool> _recalcularLotes(Map<String, DatosEstadoDescarga> dl) async {
    var changed = false;
    for (final batchKey in _batchTrackIds.keys.toList()) {
      final trackIds = _batchTrackIds[batchKey]!;
      if (trackIds.isEmpty) {
        _batchTrackIds.remove(batchKey);
        continue;
      }
      // Saltar lotes ya completados — tracks compartidos re-descargados por
      // otra playlist no deben regresar el estado del lote.
      final estadoLotePrev = dl[batchKey]?.estado;
      if (estadoLotePrev == EstadoDescarga.completado) continue;

      int completados = 0;
      int detenidos = 0;
      for (final id in trackIds) {
        final st = dl[id]?.estado;
        if (st == EstadoDescarga.completado) {
          completados++;
        } else if (st == EstadoDescarga.ninguno || st == EstadoDescarga.interrumpido) {
          detenidos++;
        }
      }
      final total = trackIds.length;
      final progreso = total > 0 ? completados / total : 0.0;
      final todoListo = (completados + detenidos) >= total;

      if (todoListo) {
        if (completados == total) {
          dl[batchKey] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
          await _finalizarLoteCompletado(batchKey, trackIds);
          _batchTrackIds.remove(batchKey);
          _reintentosAutoPorLote.remove(batchKey);
          _reintentosFallidosPorLote.remove(batchKey);
        } else {
          // Incompleto: mantener el lote vivo para que completar los rezagados
          // más tarde (manual o vía retry) pueda elevarlo a completado.
          // Auto-retry hasta _maxReintentosAutoLote veces para que el lote
          // quede verde sin intervención manual.
          dl[batchKey] = DatosEstadoDescarga(estado: EstadoDescarga.ninguno, progreso: progreso);
          final retryCount = _reintentosAutoPorLote[batchKey] ?? 0;
          // Recolectar los IDs fallidos de este lote.
          final failedIds = <String>{};
          for (final id in trackIds) {
            final st = dl[id]?.estado;
            if (st == EstadoDescarga.interrumpido || st == EstadoDescarga.ninguno) {
              failedIds.add(id);
            }
          }
          // Solo reintentar si hay fallos NUEVOS (no en _reintentosFallidosPorLote).
          final yaFallidos = _reintentosFallidosPorLote[batchKey] ?? {};
          final nuevosFallos = failedIds.difference(yaFallidos);
          if (retryCount < _maxReintentosAutoLote &&
              _datosLote.containsKey(batchKey) && nuevosFallos.isNotEmpty) {
            _reintentosAutoPorLote[batchKey] = retryCount + 1;
            _reintentosFallidosPorLote[batchKey] = yaFallidos.union(nuevosFallos);
            _log.i('[lote] auto-retry #$retryCount para $batchKey (${nuevosFallos.length} fallos nuevos, ${yaFallidos.length} previos)');
            final bk = batchKey;
            Future.delayed(const Duration(seconds: 15), () {
              if (_batchTrackIds.containsKey(bk) && _datosLote.containsKey(bk)) {
                reintentarTracksFallidosLote(bk);
              }
            });
          }
        }
        changed = true;
      } else if (completados > 0) {
        dl[batchKey] = DatosEstadoDescarga(estado: EstadoDescarga.enProgreso, progreso: progreso);
        changed = true;
      }
    }
    return changed;
  }
}