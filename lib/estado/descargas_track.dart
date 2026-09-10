// ─────────────────────────────────────────────────────────────
// descargas_track.dart — PART de cubit_descargas.dart: getter de
// tracks completados para Mi Espacio (FeedItems construidos desde
// _metaTrack con fallback a parsing de key), asegurado de metadata
// de tracks rescatados (ya descargados, preservando carátulas) y el
// despacho de un track dentro de un lote (construye la metadata
// común y delega en despacharDescargas).
// Se conecta con: descargas_track_borrar.dart (misma library).
// Parte del flujo: descargas (Mi Espacio y cola de lotes).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Tracks completados y despacho de lote. Mixin aplicado en CubitDescargas.
mixin DescargasTrack on DescargasTrackBatch {
  /// Devuelve FeedItems de TODOS los tracks descargados completados (de lotes
  /// e individuales). La metadata viene de [_metaTrack]; fallback a parsing de
  /// key solo cuando falta la metadata (poco probable).
  List<ItemFeed> get tracksCompletados {
    final result = <ItemFeed>[];
    for (final entry in state.descargas.entries) {
      if (entry.value.estado != EstadoDescarga.completado) continue;
      if (!entry.key.startsWith('track_')) continue;
      // Saltar keys de subtareas (_audio, _lyrics, _video) — solo baseId tiene metadata.
      if (entry.key.endsWith('_audio') || entry.key.endsWith('_lyrics') || entry.key.endsWith('_video')) continue;
      final meta = _metaTrack[entry.key];
      if (meta != null) {
        // Preferir la ruta local de carátula (JPG en disco) sobre la URL.
        final cover = (meta.coverPath != null && meta.coverPath!.isNotEmpty)
            ? meta.coverPath
            : meta.coverUrl;
        result.add(ItemFeed(
          id: meta.trackId,
          type: 'track', name: meta.name,
          artists: meta.artist, coverUrl: cover,
          source: meta.source,
        ));
        continue;
      }
      // Fallback: parsear la key (solo seguro cuando el ID no tiene guiones bajos).
      final parts = entry.key.split('_');
      if (parts.length < 2) continue;
      final fallbackId = parts.sublist(1, parts.length - 1).join('_');
      final fallbackSrc = parts.last;
      String? fallbackName;
      String? fallbackArtist;
      String? fallbackCover;
      for (final m in _metaTrack.values) {
        if (m.trackId == fallbackId) {
          fallbackName = m.name;
          fallbackArtist = m.artist;
          fallbackCover = m.coverUrl;
          break;
        }
      }
      result.add(ItemFeed(
        id: fallbackId,
        type: 'track', name: fallbackName ?? '', artists: fallbackArtist,
        coverUrl: fallbackCover, source: fallbackSrc,
      ));
    }
    return result;
  }

  /// Asegura que [_metaTrack] tenga una entrada para un track rescatado (ya
  /// descargado). Preserva la metadata de carátula existente si hay, si no usa
  /// los datos del lote.
  @override
  void _asegurarMetaTrack(String baseId, String normalizedId, Map<String, dynamic> trackMap, String source) {
    final existing = _metaTrack[baseId];
    if (existing != null && (existing.coverUrl?.isNotEmpty == true || existing.coverPath?.isNotEmpty == true)) {
      return;
    }
    _metaTrack[baseId] = _InfoTrack(
      normalizedId,
      (trackMap['track_title'] as String?) ?? '',
      trackMap['artist_name'] as String?,
      trackMap['cover_url'] as String?,
      source,
    );
  }

  /// Lógica compartida para despachar un track de un lote (álbum/playlist).
  /// Extrae la metadata común de [trackMap] y despacha audio/video/letras vía
  /// despacharDescargas.
  @override
  void _despacharTrackLote(
    Map<String, dynamic> trackMap,
    String trackId,
    String source,
    AjustesDescarga ajustes, {
    String? calidadForzada,
  }) {
    final normalizedId = normalizarId(trackId);
    final metaComun = construirMetaTrack(
      trackId: trackId,
      trackTitle: (trackMap['track_title'] as String?) ?? '',
      artistName: (trackMap['artist_name'] as String?) ?? '',
      albumName: (trackMap['album_name'] as String?) ?? '',
      source: source,
      isrc: (trackMap['isrc'] as String?) ?? '',
      durationMs: (trackMap['duration_ms'] as int?) ?? 0,
      coverUrl: trackMap['cover_url'] as String?,
    );
    final baseId = 'track_${normalizedId}_$source';
    _metaTrack[baseId] = _InfoTrack(
      normalizedId,
      (trackMap['track_title'] as String?) ?? '',
      trackMap['artist_name'] as String?,
      trackMap['cover_url'] as String?,
      source,
      null,
      (trackMap['isrc'] as String?) ?? '',
    );
    // Despacho directo: ya estamos dentro de la cola de lote (FIFO), así que
    // no se vuelve a encolar — el cubit ve este método por la cadena de mixins.
    despacharTrackIndividual(
      metaComun: metaComun,
      ajustes: ajustes,
      baseId: baseId,
      calidadForzada: calidadForzada,
    );
  }
}