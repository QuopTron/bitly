// ─────────────────────────────────────────────────────────────
// descargas_carga_tracks.dart — PART de cubit_descargas.dart:
// restauración de tracks individuales desde download_history: suma
// fingerprints (nombre + ISRC) para marcar como descargado en
// CUALQUIER extensión, verifica que el archivo exista y sea audio
// reproducible (si no, busca alternativa o lo marca interrumpido
// para permitir re-descarga) y puebla _metaTrack con nombres y
// carátulas.
// Se conecta con: descargas_polling.dart (misma library).
// Parte del flujo: descargas (carga del historial).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Carga de tracks del historial. Mixin aplicado en CubitDescargas.
mixin DescargasCargaTracks on DescargasPolling {
  /// Bloque 1 de _cargarHistorial: tracks individuales desde la BD.
  /// Devuelve (fingerprints, items completados, cambió algo).
  Future<(Set<String>, Map<String, DatosEstadoDescarga>, bool)> _cargarHistorialTracks() async {
    final fps = <String>{};
    final completados = <String, DatosEstadoDescarga>{};
    var cambiado = false;

    final historialJson = await _downloadCache.getHistorialDescargas();
    if (historialJson.isNotEmpty && historialJson != '[]') {
      final lista = jsonDecode(historialJson) as List;
      for (final e in lista) {
        final m = e as Map<String, dynamic>;
        final trackName = (m['track_name'] ?? m['trackName'] ?? '') as String;
        final artistName = (m['artist_name'] ?? m['artistName'] ?? '') as String;
        if (trackName.isNotEmpty) {
          fps.add(huellaDesdeNombre(trackName, artistName));
        }
        // Fingerprint ISRC: la misma grabación de CUALQUIER proveedor lleva el
        // mismo ISRC, así un track descargado bajo una extensión se ve como
        // descargado en todas las demás aunque nombre/artista difieran.
        final isrc = (m['isrc'] ?? '').toString();
        if (isrc.isNotEmpty) {
          fps.add(huellaIsrc(isrc));
        }
        var src = (m['providerSource'] ?? m['service'] ?? '') as String;
        if (src.isEmpty) src = 'download';
        final rawId = (m['id'] ?? m['providerTrackId'] ?? '') as String;
        if (rawId.isEmpty) continue;
        // Normalizar el providerTrackId para que coincida con las keys de
        // iniciarDescargaAlbum / iniciarDescargaPlaylist.
        final idNormalizado = normalizarId(rawId);
        final key = 'track_${idNormalizado}_$src';
        // Saltar tracks ya confirmados ausentes — evita el loop donde
        // _cargarHistorial reprocesa la misma entrada sin archivo.
        if (_historialSaltados.contains(key)) continue;
        _idsTracksDescargados.add(idNormalizado);
        // Verificar que el archivo exista Y sea audio reproducible antes de
        // marcarlo completado. Un FLAC amazon encriptado existe en disco pero
        // NO es reproducible — marcarlo completado mostraría un punto verde
        // falso.
        final rutaArchivo = (m['file_path'] ?? '').toString();
        if (rutaArchivo.isNotEmpty) {
          final file = File(rutaArchivo);
          final existe = await file.exists().catchError((_) => false);
          if (!existe) {
            // La ruta de la BD no existe — buscar alternativa (el decrypt pudo
            // renombrar p.ej. .flac → .dec.flac, o un proveedor en carrera
            // guardó otra extensión).
            final alt = await _buscarArchivoAlternativo(key, rutaArchivo);
            if (alt != null) {
              _log.i('[cargarHistorial] archivo ausente en $rutaArchivo pero se encontró alternativa: $alt para $key');
              completados[key] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
              try {
                await _downloadCache.actualizarRutaArchivo(idNormalizado, alt);
              } catch (_) {}
            } else {
              completados[key] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido);
              _idsTracksDescargados.remove(idNormalizado);
              _historialSaltados.add(key);
              _log.w('[cargarHistorial] archivo ausente en disco: $rutaArchivo para $key — se quitó de descargados para permitir re-descarga');
            }
          } else if (!await _esAudioDecodificable(file)) {
            // Existe pero no es reproducible (DRM encriptado, corrupto...).
            final alt = await _buscarArchivoAlternativo(key, rutaArchivo);
            if (alt != null) {
              _log.i('[cargarHistorial] archivo no reproducible en $rutaArchivo pero se encontró alternativa: $alt para $key');
              completados[key] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
              try {
                await _downloadCache.actualizarRutaArchivo(idNormalizado, alt);
              } catch (_) {}
            } else {
              completados[key] = const DatosEstadoDescarga(estado: EstadoDescarga.interrumpido);
              _idsTracksDescargados.remove(idNormalizado);
              _historialSaltados.add(key);
              _log.w('[cargarHistorial] archivo no reproducible: $rutaArchivo para $key — se quitó de descargados para permitir re-descarga');
            }
          } else {
            completados[key] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
          }
        } else {
          completados[key] = const DatosEstadoDescarga(estado: EstadoDescarga.completado, progreso: 1.0);
        }
        cambiado = true;
        final coverUrl = (m['cover_url'] ?? m['coverUrl'] ?? '') as String;
        var coverPath = (m['cover_path'] ?? m['coverPath'] ?? '') as String;
        // Backfill de carátula: los tracks descargados ANTES del fix que
        // incluye cover_url en los lotes quedaron sin carátula en la BD.
        // Si no hay cover guardado, buscar en disco por isrc/id/nombre (RPC
        // barato a Go que solo hace stat de archivos — sin red). Si el cover
        // ya se guardó bajo alguna de esas keys (p.ej. por un like del mismo
        // track), se recupera y se persiste en la fila.
        if (coverUrl.isEmpty && coverPath.isEmpty) {
          try {
            final recuperada = await _backend.getCoverPathForTrack(
              trackId: rawId,
              isrc: isrc,
              trackName: trackName,
              artistName: artistName,
              coverUrl: '',
            );
            if (recuperada != null && recuperada.isNotEmpty) {
              coverPath = recuperada;
              try {
                await _downloadCache.actualizarCaratulaTrack(
                  rawId, '', recuperada);
              } catch (_) {}
            }
          } catch (_) {}
        }
        // No pisar una entrada en memoria con carátulas válidas con carátulas
        // null de la BD (entradas viejas sin cover_url por fallbacks
        // incompletos al momento de descargar).
        final existente = _metaTrack[key];
        final existenteTieneCover = existente?.coverUrl?.isNotEmpty == true ||
            existente?.coverPath?.isNotEmpty == true;
        if (!existenteTieneCover) {
          _metaTrack[key] = _InfoTrack(
            idNormalizado,
            trackName,
            artistName.isNotEmpty ? artistName : null,
            coverUrl.isNotEmpty ? coverUrl : null,
            src,
            coverPath.isNotEmpty ? coverPath : null,
          );
        }
      }
    }
    return (fps, completados, cambiado);
  }
}