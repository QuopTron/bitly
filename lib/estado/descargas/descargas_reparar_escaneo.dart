// ─────────────────────────────────────────────────────────────
// descargas_reparar_escaneo.dart — PART de cubit_descargas.dart:
// escaneo único de arranque que detecta archivos descargados que NO
// son audio reproducible (p.ej. streams amazon encriptados guardados
// antes del decrypt por ffmpeg-kit), los borra junto con sus filas
// de BD y los re-descarga automáticamente reconstruyendo la
// estrategia desde la fila de historial.
// Se conecta con: descargas_reparar_decrypt.dart (misma library).
// Parte del flujo: descargas (reparación de arranque).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Escaneo de arranque de descargas rotas. Mixin aplicado en CubitDescargas.
mixin DescargasRepararEscaneo on DescargasRepararDecrypt {
  /// Escaneo único de arranque que detecta archivos descargados que NO son
  /// audio reproducible. Se borran, se quitan sus filas de BD y se
  /// re-descargan automáticamente.
  Future<void> _repararDescargasRotas() async {
    if (_reparacionIntentada) return;
    _reparacionIntentada = true;
    try {
      final historialJson = await _downloadCache.getHistorialDescargas();
      if (historialJson.isEmpty || historialJson == '[]') return;
      final lista = jsonDecode(historialJson) as List;
      final rotas = <Map<String, dynamic>>[];
      for (final e in lista) {
        final m = e as Map<String, dynamic>;
        final fp = (m['file_path'] ?? '').toString();
        if (fp.isEmpty) continue;
        final file = File(fp);
        if (!await file.exists()) continue;
        if (!await _esAudioDecodificable(file)) {
          rotas.add(m);
          _log.w('[CubitDescargas] Descarga corrupta detectada: $fp');
        }
      }
      if (rotas.isEmpty) return;
      _log.w('[CubitDescargas] Reparando ${rotas.length} descarga(s) corrupta(s)...');

      // Quitar filas rotas de la BD y borrar los archivos inutilizables.
      final idsRotas = rotas
          .map((m) => (m['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
      if (idsRotas.isNotEmpty) {
        await _downloadCache.borrarTracksDescargados(idsRotas);
      }
      for (final m in rotas) {
        try {
          final file = File((m['file_path'] ?? '').toString());
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      await di.sl<CacheBiblioteca>().invalidarTodo();

      // Re-descargar cada track reparado (usa el nuevo decrypt al descargar).
      for (final m in rotas) {
        await _redescargarTrackRoto(m);
      }
    } catch (e) {
      _log.e('[CubitDescargas] error de reparación: $e');
    }
  }

  /// Re-descarga un track roto descubierto por [_repararDescargasRotas],
  /// reconstruyendo la estrategia de despacho desde su fila de historial.
  Future<void> _redescargarTrackRoto(Map<String, dynamic> m) async {
    try {
      final trackId = ((m['providerTrackId'] ?? m['id']) ?? '').toString();
      if (trackId.isEmpty) return;
      final src = ((m['providerSource'] ?? m['service']) ?? '').toString();
      if (src.isEmpty) return; // sin fuente conocida no se puede re-descargar

      final baseId = 'track_${normalizarId(trackId)}_$src';
      if (state.descargas[baseId]?.estado == EstadoDescarga.enProgreso) return;

      final metaComun = <String, dynamic>{
        'track_id': trackId,
        'item_id': (m['id'] ?? trackId).toString(),
        'track_title': (m['track_name'] ?? '').toString(),
        'artist_name': (m['artist_name'] ?? '').toString(),
        'album_name': (m['album_name'] ?? '').toString(),
        'source': src,
        'isrc': (m['isrc'] ?? '').toString(),
        'duration_ms': (m['duration'] ?? 0),
        if ((m['cover_url'] ?? '').toString().isNotEmpty)
          'cover_url': (m['cover_url'] ?? '').toString(),
      };
      await despacharTrackIndividual(
        metaComun: metaComun,
        ajustes: const AjustesDescarga(),
        baseId: baseId,
      );
    } catch (e) {
      _log.e('[CubitDescargas] error de re-descarga: $e');
    }
  }
}