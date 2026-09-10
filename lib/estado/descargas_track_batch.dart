// ─────────────────────────────────────────────────────────────
// descargas_track_batch.dart — PART de cubit_descargas.dart:
// actualización del estado del lote (álbum/playlist) padre cuando se
// borra UN track: quita el track de _batchTrackIds y de
// _datosLote.tracks, y recalcula el estado del lote (completado si
// todos terminaron —persistiéndolo—, en progreso si quedan activos,
// ninguno si quedó incompleto, o se elimina el lote si no le quedan
// tracks). Matchea por ID normalizado porque el audioId del lote
// puede usar otra fuente que la del track (discrepancias de
// proveedor entre lote y poll).
// Se conecta con: descargas_track_borrar.dart (misma library).
// Parte del flujo: descargas (borrar track → estado del lote).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Actualización del lote tras borrar un track. Mixin en CubitDescargas.
mixin DescargasTrackBatch on DescargasTrackBorrar {
  @override
  Future<void> _actualizarEstadoLoteTrasBorrar(
      String normalizedId, Map<String, DatosEstadoDescarga> dl) async {
    for (final batchKey in _batchTrackIds.keys.toList()) {
      final trackIds = _batchTrackIds[batchKey]!;
      // Encontrar el audioId de este lote que coincide con el ID normalizado.
      String? matchedAudioId;
      for (final tid in trackIds) {
        final tidParts = tid.split('_');
        if (tidParts.length >= 3) {
          final tidNormId = tidParts.sublist(1, tidParts.length - 1).join('_');
          if (tidNormId == normalizedId) {
            matchedAudioId = tid;
            break;
          }
        }
      }
      if (matchedAudioId != null) {
        trackIds.remove(matchedAudioId);
        // También quitar de _datosLote.tracks para mantener la metadata del lote.
        final batchData = _datosLote[batchKey];
        if (batchData != null) {
          batchData.tracks.removeWhere((t) {
            final tNormId = normalizarId((t['track_id'] as String?) ?? '');
            return tNormId == normalizedId;
          });
        }
        if (trackIds.isNotEmpty) {
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
          final todoListo = (completados + detenidos) >= total;
          if (todoListo && completados == total) {
            dl[batchKey] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
            await _finalizarLoteCompletado(batchKey, trackIds);
            _batchTrackIds.remove(batchKey);
          } else {
            dl[batchKey] = DatosEstadoDescarga(
              estado: todoListo ? EstadoDescarga.ninguno : (completados > 0 ? EstadoDescarga.enProgreso : EstadoDescarga.ninguno),
              progreso: total > 0 ? completados / total : 0.0,
            );
          }
        } else {
          dl.remove(batchKey);
          _batchTrackIds.remove(batchKey);
          _datosLote.remove(batchKey);
        }
        break;
      }
    }
  }
}