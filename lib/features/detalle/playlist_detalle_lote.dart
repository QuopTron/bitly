// ─────────────────────────────────────────────────────────────
// playlist_detalle_lote.dart — PART de playlist_detalle_pagina.dart:
// reconstruye el DetallePlaylist desde el lote descargado cuando no
// hay red ni caches. Soporta lotes nuevos (objetos {id, name,
// artist, cover}) y viejos (state-keys resueltas con el historial
// de descargas + metadata viva del cubit).
// Se conecta con: playlist_detalle_pagina.dart (misma library) +
// cache_descargas + cubit_descargas.
// Parte del flujo: Detalle → playlist (fallback offline).
// ─────────────────────────────────────────────────────────────

part of 'playlist_detalle_pagina.dart';

/// Arma un DetallePlaylist desde los lotes descargados sin red.
Future<DetallePlaylist?> _construirDesdeLotePlaylist(
  _PlaylistDetallePaginaState st,
) async {
  final dlCache = sl<CacheDescargas>();
  var lote = await dlCache.getLotePorItem(
    'playlist',
    st.widget.collectionId,
    st.widget.source,
  );
  if (lote == null && st.widget.source.isNotEmpty) {
    lote = await dlCache.getLotePorItem('playlist', st.widget.collectionId, '');
  }
  if (lote == null || lote.trackIds == null || lote.trackIds!.isEmpty) {
    return null;
  }

  final List<dynamic> idsCrudos;
  try {
    idsCrudos = jsonDecode(lote.trackIds!) as List<dynamic>;
  } catch (_) {
    return null;
  }

  // Los lotes nuevos guardan objetos {id, name, artist, cover}; los viejos
  // guardan solo state-keys y se resuelven con el historial de descargas.
  final enriquecido = idsCrudos.isNotEmpty && idsCrudos.first is Map<String, dynamic>;
  Map<String, Map<String, dynamic>>? mapaHistorial;
  if (!enriquecido) {
    final historial =
        jsonDecode(await dlCache.getHistorialDescargas()) as List<dynamic>;
    mapaHistorial = <String, Map<String, dynamic>>{};
    for (final entry in historial) {
      final m = entry as Map<String, dynamic>;
      mapaHistorial[(m['id'] as String?)?.toLowerCase() ?? ''] = m;
    }
  }

  final tracks = <TrackDetalle>[];
  for (final raw in idsCrudos) {
    if (enriquecido) {
      final obj = raw as Map<String, dynamic>;
      final stateKey = (obj['id'] ?? '') as String;
      final partes = stateKey.split('_');
      final idNorm = partes.length >= 3
          ? partes.sublist(1, partes.length - 1).join('_')
          : stateKey;
      final nombre = (obj['name'] ?? '') as String;
      tracks.add(TrackDetalle(
        trackId: idNorm,
        name: nombre.isNotEmpty ? nombre : idNorm,
        artistName: (obj['artist'] ?? '') as String,
        coverUrl: (obj['cover'] ?? '') as String,
        provider: st.widget.source,
      ));
    } else {
      final stateKey = raw as String;
      final partes = stateKey.split('_');
      if (partes.length < 3) continue;
      final idNorm = partes.sublist(1, partes.length - 1).join('_');
      final meta = mapaHistorial?[idNorm] ?? mapaHistorial?[stateKey.toLowerCase()];
      final vivo = sl<CubitDescargas>().metaTrackPara(stateKey);
      final nombreHist = (meta?['track_name'] as String?) ?? '';
      final artistaHist = (meta?['artist_name'] as String?) ?? '';
      final caratulaHist = (meta?['cover_url'] as String?) ?? '';
      tracks.add(TrackDetalle(
        trackId: (meta?['id'] as String?) ?? idNorm,
        name: nombreHist.isNotEmpty
            ? nombreHist
            : (vivo?.name.isNotEmpty == true ? vivo!.name : idNorm),
        durationMs: (meta?['duration'] as num?)?.toInt() ?? 0,
        isrc: meta?['isrc'] as String? ?? '',
        coverUrl: caratulaHist.isNotEmpty ? caratulaHist : (vivo?.cover ?? ''),
        coverPath: (meta?['cover_path'] as String?) ?? '',
        artistName: artistaHist.isNotEmpty
            ? artistaHist
            : (vivo?.artist ?? ''),
        albumName: (meta?['album_name'] as String?) ?? '',
        provider: (meta?['providerSource'] as String?) ?? st.widget.source,
      ));
    }
  }

  if (tracks.isEmpty) return null;
  return DetallePlaylist(
    id: lote.itemId ?? st.widget.collectionId,
    name: lote.name ?? st.widget.playlistName,
    itemCount: tracks.length,
    tracks: tracks,
  );
}