// ─────────────────────────────────────────────────────────────
// descargas_poll_persistir.dart — PART de cubit_descargas.dart:
// persistencia de un track completado en el poll: carátula local con
// backoff exponencial (3 intentos), fila en BD (guardarTrackDescargado)
// con fallback al ISRC cuando el provider id viene vacío, fingerprint
// nombre+artista, marca de persistido (para no re-guardar en polls
// siguientes) y registro del archivo en el mapa local del player
// para reproducir sin esperar una recarga de BD.
// Se conecta con: descargas_poll_finalizar.dart (misma library).
// Parte del flujo: descargas (poll → persistencia en BD).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Persistencia de tracks completados. Mixin aplicado en CubitDescargas.
mixin DescargasPollPersistir on DescargasPollFinalizar {
  /// Guarda el track completado en BD + carátula + fingerprint + player.
  @override
  Future<void> _persistirCompletado(
    String rawId,
    String stateKey,
    String playablePath,
    String trackName,
    String artistName,
    Set<String> fps,
  ) async {
    final meta = _metaTrack[stateKey];
    var trackId = meta?.trackId ?? (stateKey.startsWith('track_') && stateKey.length > 6
        ? stateKey.substring(6, stateKey.lastIndexOf('_'))
        : rawId);
    final src = meta?.source ?? (stateKey.contains('_') ? stateKey.split('_').last : '');
    // Un track del feed puede llegar con provider id vacío (pero ISRC válido)
    // — amazon/otros resuelven un archivo real por ISRC. Fallback al ISRC para
    // persistir una fila identificable, borrable y reproducible.
    final isrc = meta?.isrc ?? '';
    if (trackId.isEmpty && isrc.isNotEmpty) {
      trackId = isrc;
    }
    // Guardar la carátula en local para persistencia offline (como los amados).
    final trackCoverUrl = meta?.coverUrl;
    String? coverPath;
    if (trackCoverUrl != null && trackCoverUrl.isNotEmpty) {
      for (var intento = 0; intento < 3; intento++) {
        try {
          final coverPathResult = await _backend.saveCover(trackCoverUrl);
          if (coverPathResult != null && coverPathResult.isNotEmpty) {
            coverPath = coverPathResult;
            break;
          }
        } catch (_) {
          coverPath = null;
        }
        if (intento < 2) {
          await Future<void>.delayed(Duration(seconds: 1 << intento));
        }
      }
      if (coverPath != null && coverPath.isNotEmpty && meta != null) {
        _metaTrack[stateKey] = _InfoTrack(
          meta.trackId, meta.name, meta.artist, meta.coverUrl, meta.source, coverPath,
        );
      }
    }
    String stripSufijo(String s) => s.endsWith('_audio') || s.endsWith('_video')
        ? s.substring(0, s.length - 6)
        : s.endsWith('_lyrics') ? s.substring(0, s.length - 7) : s;
    unawaited(_downloadCache.guardarTrackDescargado(
      id: trackId,
      trackName: trackName.isNotEmpty ? trackName : (isrc.isNotEmpty ? isrc : rawId),
      artistName: artistName.isNotEmpty ? artistName : '',
      isrc: isrc.isNotEmpty ? isrc : null,
      service: src,
      filePath: playablePath.isNotEmpty ? playablePath : null,
      providerTrackId: stripSufijo(rawId),
      providerSource: src,
      coverUrl: trackCoverUrl,
      coverPath: coverPath,
    ));
    final fpName = trackName.isNotEmpty ? trackName : (isrc.isNotEmpty ? isrc : rawId);
    final fpArtist = trackName.isNotEmpty ? artistName : '';
    fps.add(huellaDesdeNombre(fpName, fpArtist));
    _completadosPersistidos.add(rawId);
    // Registrar el archivo en el mapa local del player para reproducir desde
    // disco sin esperar una recarga de BD.
    if (playablePath.isNotEmpty) {
      di.sl<CubitReproductor>().registrarArchivoLocal(
        trackId: trackId,
        filePath: playablePath,
        providerTrackId: stripSufijo(rawId),
        trackName: trackName.isNotEmpty ? trackName : null,
        artistName: artistName.isNotEmpty ? artistName : null,
        isrc: isrc.isNotEmpty ? isrc : null,
      );
    }
  }
}