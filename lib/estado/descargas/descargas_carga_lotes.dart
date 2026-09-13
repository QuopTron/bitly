// ─────────────────────────────────────────────────────────────
// descargas_carga_lotes.dart — PART de cubit_descargas.dart:
// restauración de lotes (álbumes/playlists) desde downloaded_batches
// (marca completado, puebla _metaLote y _batchTrackIds) y backfill
// de carátulas: tracks sin cover adoptan la del álbum amado y lotes
// sin cover adoptan la del primer track con una.
// Parte del flujo: descargas (carga del historial).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

mixin DescargasCargaLotes on DescargasCargaTracks {
  /// Bloque 2 de _cargarHistorial: lotes desde la BD + backfill de carátulas.
  Future<(Map<String, DatosEstadoDescarga>, bool)> _cargarHistorialLotes() async {
    final completados = <String, DatosEstadoDescarga>{};
    var cambiado = false;

    final lotesJson = await _downloadCache.getLotesDescargados(
      desde: _ultimoTimestampLotes,
    );
    final mapaTrackALote = <String, String>{};
    if (lotesJson.isNotEmpty && lotesJson != '[]') {
      final lista = jsonDecode(lotesJson) as List;
      for (final e in lista) {
        final m = e as Map<String, dynamic>;
        final batchKey = (m['batch_key'] ?? '') as String;
        if (batchKey.isEmpty) continue;
        completados[batchKey] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
        cambiado = true;
        final nombre = (m['name'] ?? '') as String;
        final itemType = (m['item_type'] ?? '') as String;
        final itemId = (m['item_id'] ?? '') as String;
        final source = (m['source'] ?? '') as String;
        if (nombre.isNotEmpty) {
          var coverUrlLote = (m['cover_url'] ?? '') as String;
          var coverPathLote = (m['cover_path'] ?? '') as String;
          if (coverUrlLote.isEmpty && coverPathLote.isEmpty) {
            final trackIdsRaw = (m['track_ids'] ?? '') as String;
            if (trackIdsRaw.isNotEmpty) {
              try {
                final idsParseados = jsonDecode(trackIdsRaw) as List;
                for (final tid in idsParseados) {
                  String stateKey;
                  if (tid is Map<String, dynamic>) {
                    stateKey = (tid['id'] ?? '') as String;
                    if (coverUrlLote.isEmpty) {
                      coverUrlLote = (tid['cover'] ?? '') as String;
                    }
                  } else {
                    stateKey = tid.toString();
                  }
                  final meta = _metaTrack[stateKey];
                  if (meta != null &&
                      ((meta.coverPath?.isNotEmpty ?? false) ||
                          (meta.coverUrl?.isNotEmpty ?? false))) {
                    coverPathLote = meta.coverPath ?? '';
                    coverUrlLote = meta.coverUrl ?? '';
                    break;
                  }
                }
              } catch (_) {}
            }
          }
          _metaLote[batchKey] = _MetaLote(
            nombre, itemType, itemId, source,
            coverUrl: coverUrlLote,
            coverPath: coverPathLote,
          );
        }
        // Mapa inverso: trackId → batchKey y _batchTrackIds para el backfill.
        final trackIdsRaw = (m['track_ids'] ?? '') as String;
        if (trackIdsRaw.isNotEmpty) {
          try {
            final idsParseados = jsonDecode(trackIdsRaw) as List;
            final idStrings = <String>[];
            for (final entry in idsParseados) {
              if (entry is String) {
                idStrings.add(entry);
              } else if (entry is Map<String, dynamic>) {
                final id = (entry['id'] ?? '') as String;
                if (id.isNotEmpty) idStrings.add(id);
              }
            }
            _batchTrackIds[batchKey] = idStrings;
            for (final stateKey in idStrings) {
              mapaTrackALote[normalizarId(stateKey)] = batchKey;
            }
          } catch (_) {}
        }
      }
    }
    _ultimoTimestampLotes = DateTime.now().toUtc().toIso8601String();

    // ── 3. Backfill: tracks con cover null adoptan la del álbum/playlist ──
    if (mapaTrackALote.isNotEmpty) {
      final cubitLikes = di.sl<CubitLikes>();
      for (final entry in _metaTrack.entries) {
        final meta = entry.value;
        if (meta.coverUrl?.isNotEmpty ?? false) continue;
        if (meta.coverPath?.isNotEmpty ?? false) continue;
        final batchKey = mapaTrackALote[meta.trackId];
        if (batchKey == null) continue;
        final bm = _metaLote[batchKey];
        if (bm == null) continue;
        final albumAmado = cubitLikes.state.todosAmados.values
            .where((i) =>
                i.type == bm.itemType &&
                normalizarId(i.id) == normalizarId(bm.itemId))
            .firstOrNull;
        final coverAlbum = albumAmado?.rutaCaratulaLocal?.isNotEmpty == true
            ? albumAmado!.rutaCaratulaLocal
            : albumAmado?.coverUrl;
        if (coverAlbum != null && coverAlbum.isNotEmpty) {
          _metaTrack[entry.key] = _InfoTrack(
            meta.trackId, meta.name, meta.artist, coverAlbum, meta.source,
            meta.coverPath,
          );
          cambiado = true;
        }
      }
    }

    // ── 3b. Backfill: lotes sin cover adoptan la del primer track con una ──
    if (mapaTrackALote.isNotEmpty) {
      final vistos = <String>{};
      for (final entry in _metaTrack.entries) {
        final meta = entry.value;
        final batchKey = mapaTrackALote[meta.trackId];
        if (batchKey == null || vistos.contains(batchKey)) continue;
        final bm = _metaLote[batchKey];
        if (bm == null || bm.coverUrl.isNotEmpty) {
          vistos.add(batchKey);
          continue;
        }
        final cover = (meta.coverPath?.isNotEmpty ?? false)
            ? meta.coverPath!
            : (meta.coverUrl ?? '');
        if (cover.isNotEmpty) {
          _metaLote[batchKey] = _MetaLote(
            bm.name, bm.itemType, bm.itemId, bm.source,
            coverUrl: bm.coverUrl.isNotEmpty ? bm.coverUrl : cover,
            coverPath: bm.coverPath.isNotEmpty ? bm.coverPath : cover,
          );
          cambiado = true;
        }
        vistos.add(batchKey);
      }
    }
    return (completados, cambiado);
  }
}