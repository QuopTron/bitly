// ─────────────────────────────────────────────────────────────
// descargas_carga_lotes.dart — PART de cubit_descargas.dart:
// restauración de lotes (álbumes/playlists) desde downloaded_batches.
//
// La fila del lote se escribe al EMPEZAR la descarga, así que acá NO
// se confía en ella: cada lote se marca completado solo si TODOS sus
// tracks están de verdad descargados (ver lote_restaurado.dart); si
// falta alguno queda parcial con su progreso y sigue vivo para que
// bajar los que faltan lo eleve a completado. Las claves que no son
// de colección (la cola de singles guarda '_singles') se descartan.
//
// El backfill de carátulas vive en
// descargas_carga_lotes_caratulas.dart.
// Se conecta con: descargas_carga_lotes_caratulas.dart (misma library).
// Parte del flujo: descargas (carga del historial).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

mixin DescargasCargaLotes on DescargasCargaLotesCaratulas {
  /// Bloque 2 de _cargarHistorial: lotes desde la BD (verificados).
  Future<(Map<String, DatosEstadoDescarga>, bool)>
  _cargarHistorialLotes() async {
    final completados = <String, DatosEstadoDescarga>{};
    var cambiado = false;

    final lotesJson = await _downloadCache.getLotesDescargados(
      desde: _ultimoTimestampLotes,
    );
    final mapaTrackALote = <String, String>{};
    final clavesBasura = <String>[];
    if (lotesJson.isNotEmpty && lotesJson != '[]') {
      final lista = jsonDecode(lotesJson) as List;
      for (final e in lista) {
        final m = e as Map<String, dynamic>;
        final batchKey = (m['batch_key'] ?? '') as String;
        if (batchKey.isEmpty) continue;
        if (!esClaveDeColeccion(batchKey)) {
          clavesBasura.add(batchKey);
          continue;
        }
        final source = (m['source'] ?? '') as String;
        final idStrings = idsStateKeysDeLote((m['track_ids'] ?? '') as String);
        final r = evaluarLoteRestaurado(
          idStrings,
          (stateKey) => _loteTrackDescargado(stateKey, source),
        );
        completados[batchKey] = estadoDeLoteRestaurado(r);
        if (!r.completo) {
          _log.i(
            '[cargarHistorial] lote parcial $batchKey: '
            '${r.listos}/${r.total} tracks en disco',
          );
        }
        cambiado = true;
        final nombre = (m['name'] ?? '') as String;
        final itemType = (m['item_type'] ?? '') as String;
        final itemId = (m['item_id'] ?? '') as String;
        if (nombre.isNotEmpty) {
          final cover = _coverDeLote(m, idStrings);
          _metaLote[batchKey] = _MetaLote(
            nombre,
            itemType,
            itemId,
            source,
            coverUrl: cover.url,
            coverPath: cover.path,
          );
        }
        // Mapa inverso: trackId → batchKey y _batchTrackIds. Los lotes
        // parciales también entran: así el poll puede elevarlos a
        // completado cuando se bajan los tracks que faltaban.
        if (idStrings.isNotEmpty) {
          _batchTrackIds[batchKey] = idStrings;
          for (final stateKey in idStrings) {
            mapaTrackALote[normalizarId(stateKey)] = batchKey;
          }
        }
      }
    }
    if (clavesBasura.isNotEmpty) {
      _log.w(
        '[cargarHistorial] descartando ${clavesBasura.length} lote(s) que no '
        'son colección: $clavesBasura',
      );
      await _downloadCache.quitarLotes(clavesBasura);
    }
    _ultimoTimestampLotes = DateTime.now().toUtc().toIso8601String();

    if (await _backfillCaratulasDeLotes(mapaTrackALote)) cambiado = true;
    return (completados, cambiado);
  }

  /// ¿La state key del lote está realmente descargada? Estado en memoria
  /// ya completado o id presente en el historial verificado de la BD.
  bool _loteTrackDescargado(String stateKey, String source) {
    if (state.descargas[stateKey]?.estado == EstadoDescarga.completado) {
      return true;
    }
    final id = idDeStateKey(stateKey, source);
    return id.isNotEmpty && _idsTracksDescargados.contains(id);
  }

  /// Carátula ya guardada del lote (URL y ruta local), o la del primer
  /// track del lote que tenga una.
  ({String url, String path}) _coverDeLote(
    Map<String, dynamic> m,
    List<String> idStrings,
  ) {
    var url = (m['cover_url'] ?? '') as String;
    var path = (m['cover_path'] ?? '') as String;
    if (url.isNotEmpty || path.isNotEmpty) return (url: url, path: path);
    for (final stateKey in idStrings) {
      final meta = _metaTrack[stateKey];
      if (meta == null) continue;
      if (meta.coverPath?.isNotEmpty ?? false) {
        return (url: meta.coverUrl ?? '', path: meta.coverPath!);
      }
      if (meta.coverUrl?.isNotEmpty ?? false) {
        return (url: meta.coverUrl!, path: '');
      }
    }
    return (url: '', path: '');
  }
}
