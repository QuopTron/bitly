// ─────────────────────────────────────────────────────────────
// descargas_inicio.dart — PART de cubit_descargas.dart: inicio de
// una descarga de track ÚNICO: chequea duplicados (por ID en el
// historial y por fingerprint nombre+artista), verifica carpeta y
// sesiones, limpia el skip de decrypt de un reintento y encola el
// track en el lote de singles de la cola FIFO. Los lotes de
// álbum/playlist viven en descargas_inicio_album.dart y
// descargas_inicio_playlist.dart.
// Se conecta con: descargas_acceso.dart (misma library).
// Parte del flujo: descargas (botón de descarga de un track).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Inicio de descargas individuales. Mixin aplicado en CubitDescargas.
mixin DescargasInicio on DescargasAcceso {
  /// Asegura que _metaTrack tenga metadata para un track rescatado (ya
  /// descargado) — implementación concreta en DescargasTrack (arriba).
  void _asegurarMetaTrack(String baseId, String normalizedId,
      Map<String, dynamic> trackMap, String source);

  /// Inicia la descarga de un track único a través de la cola FIFO. El track
  /// se encola y se procesa en orden — NO corre en paralelo con lotes en curso.
  void iniciarDescarga(String id, {Map<String, dynamic>? strategy}) async {
    if (state.descargas[id]?.estado == EstadoDescarga.enProgreso) return;
    if (state.descargas[id]?.estado == EstadoDescarga.completado) return;
    // Si el track ya está en el historial, saltar la re-descarga.
    final s = strategy ?? {'type': 'audio'};
    final trackId = (s['track_id'] ?? s['item_id'] ?? '').toString();
    if (trackId.isNotEmpty) {
      final normalizedId = normalizarId(trackId);
      if (_idsTracksDescargados.contains(normalizedId)) {
        _log.i('[iniciarDescarga] skip duplicado por ID: $normalizedId');
        return;
      }
    }
    // Duplicado agnóstico de fuente por fingerprint nombre+artista.
    final trackName = (s['track_title'] ?? '') as String;
    final artistName = (s['artist_name'] ?? '') as String;
    if (trackName.isNotEmpty && state.huellasDescargadas.contains(
        huellaDesdeNombre(trackName, artistName))) {
      _log.i('[iniciarDescarga] skip duplicado por fingerprint: $trackName de $artistName');
      return;
    }
    if (!await _verificarCarpetaDescargas()) return;
    if (!await _verificarSesionesAntesDeDescargar()) return;
    // Permitir reintento de un decrypt fallido limpiando el skip del item.
    final retryItemId = (s['item_id'] ?? s['track_id'] ?? '').toString();
    if (retryItemId.isNotEmpty) _decryptClienteSaltado.remove(retryItemId);

    final source = (s['source'] ?? '').toString();
    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    dl[id] = const DatosEstadoDescarga(estado: EstadoDescarga.enCola, progreso: 0.0);
    emit(state.copiarCon(descargas: dl));
    _log.i('[iniciarDescarga] encolando track único: $id source=$source');
    _colaDescargas.add(_TrackEnCola(s, trackId, source, const AjustesDescarga(), null, '_singles'));
    _asegurarPolling();
    _procesarColaDescargas();
  }
}