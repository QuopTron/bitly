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
  /// Implementado por [DescargasLoteCaratula] (mixin combinado después en
  /// CubitDescargas): resuelve nombre y carátula de un lote completado.
  @protected
  Future<_DatosCaratulaLote> _resolverDatosLote({
    required String itemType,
    required String itemId,
    required List<String> trackIds,
    _DatosLote? batchData,
  });

  /// Persiste un lote completado y refresca los caches.
  Future<void> _finalizarLoteCompletado(
    String batchKey,
    List<String> trackIds,
  ) async {
    if (_lotesGuardadosCompletados.contains(batchKey)) return;
    _lotesGuardadosCompletados.add(batchKey);
    // Solo álbumes y playlists: la cola de singles usa la key interna
    // '_singles', que no es una colección y no debe persistirse como lote.
    if (!esClaveDeColeccion(batchKey)) return;
    final parts = batchKey.split('_');
    if (parts.length < 3) return;
    final itemType = parts[0];
    final src = parts.last;
    final itemId = parts.sublist(1, parts.length - 1).join('_');
    final batchData = _datosLote[batchKey];
    // Nombre y carátula con fallbacks: _datosLote puede estar vacío cuando el
    // lote terminó de a un track suelto, y antes eso dejaba el álbum sin
    // nombre y sin portada en la BD (tarjeta gris para siempre).
    final resuelto = await _resolverDatosLote(
      itemType: itemType,
      itemId: itemId,
      trackIds: trackIds,
      batchData: batchData,
    );
    final batchName = resuelto.nombre;
    final batchCover = resuelto.coverUrl;
    // Reusar la carátula que ya está en disco (el like o un track del lote ya
    // la bajó) y, si no hay, bajarla con 3 intentos y backoff exponencial.
    String batchCoverPath = resuelto.coverPath;
    if (batchCoverPath.isEmpty && batchCover.isNotEmpty) {
      for (var intento = 0; intento < 3; intento++) {
        final saved = await _backend.saveCover(
          batchCover,
          keys: clavesCaratula(
            trackId: itemId,
            nombre: batchName,
            artista:
                batchData?.tracks.isNotEmpty == true
                    ? (batchData!.tracks.first['artist_name'] as String?)
                    : null,
          ),
        );
        if (saved != null && saved.isNotEmpty) {
          batchCoverPath = saved;
          break;
        }
        if (intento < 2) {
          await Future<void>.delayed(Duration(seconds: 1 << intento));
        }
      }
      if (batchCoverPath.isEmpty) {
        _log.w('[Descargas] sin carátula local para el lote $batchKey');
      }
    }
    _metaLote[batchKey] = _MetaLote(
      batchName,
      itemType,
      itemId,
      src,
      coverUrl: batchCover,
      coverPath: batchCoverPath,
    );
    await _downloadCache.guardarLoteDescargado(
      batchKey,
      itemType,
      itemId,
      src,
      batchName,
      trackIds: trackIds,
      coverUrl: batchCover,
      coverPath: batchCoverPath,
    );
    // La biblioteca local (tabla albums) es lo que leen las vistas de detalle
    // al abrir el álbum sin red: se le deja la misma carátula.
    await _contentLote.actualizarCaratulaAlbum(
      itemId,
      batchCover,
      batchCoverPath,
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
