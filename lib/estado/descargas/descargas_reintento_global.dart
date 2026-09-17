// ─────────────────────────────────────────────────────────────
// descargas_reintento_global.dart — PART de cubit_descargas.dart:
// reintento manual de TODO lo que quedó cortado, que es lo que pide
// el usuario desde Mi Espacio (banner ámbar) o desde el aviso de
// descarga (tarjeta de fallo).
//
// Cubre los dos casos que antes no existían juntos:
//   • lotes (álbum/playlist) → reusa sus datos originales y encola
//     solo los tracks que NO quedaron completados;
//   • canciones sueltas (bajadas desde la tarjeta de una canción) →
//     no tienen lote, así que se reencolan con el trackMap del
//     intento original y los ajustes ACTUALES del usuario.
//
// Todo pasa por la MISMA cola FIFO: reintentar nunca abre un segundo
// camino de descarga ni descargas en paralelo.
//
// Cadena de mixins: … → inicio_playlist → reintento_global.
// Se conecta con: descargas_reintentar.dart (reintento de lote) y
// descargas_inicio.dart (ajustes y cola).
// Parte del flujo: descargas (reintentos manuales).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Reintentos manuales. Mixin aplicado en CubitDescargas.
mixin DescargasReintentoGlobal on DescargasInicioPlaylist {
  /// Reintenta lo que quedó interrumpido: primero los lotes (álbum/playlist) y
  /// después las canciones sueltas. Sin esto, una canción bajada desde el
  /// botón de su tarjeta se quedaba en rojo para siempre.
  @override
  void reintentarTodosInterrumpidos() {
    final lotes =
        state.descargas.entries
            .where(
              (e) =>
                  (e.value.estado == EstadoDescarga.interrumpido ||
                      e.value.estado == EstadoDescarga.ninguno) &&
                  (e.key.startsWith('album_') ||
                      e.key.startsWith('playlist_')) &&
                  _datosLote.containsKey(e.key),
            )
            .map((e) => e.key)
            .toList();
    for (final lote in lotes) {
      reintentarTracksFallidosLote(lote);
    }
    _reintentarTracksSueltos();
  }

  /// Reencola las canciones sueltas que quedaron interrumpidas (claves
  /// `track_<id>_<fuente>`, sin lote detrás). Los ajustes se leen UNA vez para
  /// que el orden de encolado sea el mismo que el de la lista.
  Future<void> _reintentarTracksSueltos() async {
    final sueltos =
        state.descargas.entries
            .where(
              (e) =>
                  e.value.estado == EstadoDescarga.interrumpido &&
                  e.key.startsWith('track_') &&
                  !e.key.endsWith('_audio') &&
                  !e.key.endsWith('_lyrics') &&
                  !e.key.endsWith('_video'),
            )
            .map((e) => e.key)
            .toList();
    if (sueltos.isEmpty) return;
    final ajustes = await ajustesDeDescarga();
    for (final baseId in sueltos) {
      await _reencolarTrackInterrumpido(baseId, ajustes: ajustes);
    }
  }

  /// Reintenta UNA canción que quedó en fallo definitivo; lo ofrece el aviso de
  /// descarga. Devuelve false si no hay datos suficientes para reintentarla
  /// (p.ej. la app se reinició y perdió el metadata del intento original).
  Future<bool> reintentarTrackFallido(String baseId) async =>
      _reencolarTrackInterrumpido(baseId);

  /// Cuerpo compartido: limpia el rastro del intento anterior y mete la canción
  /// en la cola FIFO con los ajustes actuales.
  Future<bool> _reencolarTrackInterrumpido(
    String baseId, {
    AjustesDescarga? ajustes,
  }) async {
    final trackMap = _trackMapPorBaseId[baseId];
    final meta = _metaTrack[baseId];
    if (trackMap == null || meta == null || meta.source.isEmpty) return false;

    // Vuelven a estar disponibles los reintentos en sitio y se limpia el rastro
    // de poll: sin eso el intento nuevo se saltaría a sí mismo y "reintentar"
    // no descargaría nada.
    _olvidarIntentos(baseId);
    _limpiarEstadoPollTrack(normalizarId(meta.trackId), baseId);

    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    dl[baseId] = const DatosEstadoDescarga(
      estado: EstadoDescarga.enCola,
      progreso: 0.0,
    );
    emit(
      state.copiarCon(
        descargas: dl,
        // Si el aviso que está en pantalla es de ESTA canción, ya no aplica.
        limpiarFalloDescarga: state.falloDescarga?.baseId == baseId,
      ),
    );
    _log.i('[cola] ↻ reintento manual de $baseId');
    _colaDescargas.add(
      _TrackEnCola(
        trackMap,
        meta.trackId,
        meta.source,
        ajustes ?? await ajustesDeDescarga(),
      ),
    );
    _procesarColaDescargas();
    return true;
  }
}
