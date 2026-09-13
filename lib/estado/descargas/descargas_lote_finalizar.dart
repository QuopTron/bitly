// ─────────────────────────────────────────────────────────────
// descargas_lote_finalizar.dart — PART de cubit_descargas.dart:
// persistencia de un lote (álbum/playlist) completamente terminado:
// guarda la carátula del lote en local (3 intentos con backoff),
// registra _metaLote y la fila en BD, e invalida los caches de
// biblioteca y detalle para que las páginas recarguen con datos
// frescos. Idempotente por lote: guardado una sola vez vía
// [_lotesGuardadosCompletados] para que un rezagado completado
// manualmente después de que el lote "parecía" terminado no duplique.
// Se conecta con: descargas_estado.dart (misma library).
// Parte del flujo: descargas (lotes completados → BD).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Finalización y persistencia de lotes. Mixin aplicado en CubitDescargas.
mixin DescargasLoteFinalizar on DescargasEstado {
  /// Persiste un lote completado y refresca los caches.
  Future<void> _finalizarLoteCompletado(String batchKey, List<String> trackIds) async {
    if (_lotesGuardadosCompletados.contains(batchKey)) return;
    _lotesGuardadosCompletados.add(batchKey);
    final parts = batchKey.split('_');
    if (parts.length < 2) return;
    final itemType = parts[0];
    final src = parts.last;
    final itemId = parts.sublist(1, parts.length - 1).join('_');
    final batchData = _datosLote[batchKey];
    final batchName = (batchData?.tracks.isNotEmpty == true)
        ? (batchData!.tracks.first['album_name'] as String? ?? '')
        : '';
    final batchCover = (batchData?.tracks.isNotEmpty == true)
        ? (batchData!.tracks.first['cover_url'] as String? ?? '')
        : '';
    // Guardar la carátula del lote en local para persistencia offline.
    // Reintentar 3 veces con backoff exponencial (igual que tracks únicos).
    String batchCoverPath = '';
    if (batchCover.isNotEmpty) {
      for (var intento = 0; intento < 3; intento++) {
        try {
          final saved = await _backend.saveCover(batchCover);
          if (saved != null && saved.isNotEmpty) {
            batchCoverPath = saved;
            break;
          }
        } catch (_) {}
        if (intento < 2) {
          await Future<void>.delayed(Duration(seconds: 1 << intento));
        }
      }
    }
    _metaLote[batchKey] = _MetaLote(batchName, itemType, itemId, src,
        coverUrl: batchCover, coverPath: batchCoverPath);
    await _downloadCache.guardarLoteDescargado(
      batchKey, itemType, itemId, src, batchName,
      trackIds: trackIds,
      coverUrl: batchCover,
      coverPath: batchCoverPath,
    );
    di.sl<CacheBiblioteca>().invalidarTodo();
    // Invalidar el detalle para que álbum/playlist recarguen con datos frescos.
    final detailCache = di.sl<CacheDetalle>();
    if (itemType == 'album') {
      await detailCache.invalidarAlbum(itemId);
    } else if (itemType == 'playlist') {
      await detailCache.invalidarPlaylist(itemId);
    }
  }
}