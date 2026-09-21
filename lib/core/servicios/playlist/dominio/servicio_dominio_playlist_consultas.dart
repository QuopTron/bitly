// ─────────────────────────────────────────────────────────────
// servicio_dominio_playlist_consultas.dart — PART de
// servicio_dominio_playlist.dart: consultas de playlists (lista del
// usuario, tracks y stats). Separado para mantener cada archivo
// dentro del límite.
// Se conecta con: caches (colecciones/detalle/favoritos) + Go.
// Parte del flujo: Mi Espacio → Playlists (lecturas).
// ─────────────────────────────────────────────────────────────

part of 'servicio_dominio_playlist.dart';

/// Consultas de playlists. Mixin combinado en ServicioDominioPlaylist.
mixin ServicioDominioPlaylistConsultas {
  /// Caché de favoritos (lo provee la clase base).
  CacheFavoritos get _fav;

  /// Todas las playlists del usuario actual.
  Future<List<PlaylistDominio>> getPorUsuario() async {
    try {
      final json = await _fav.getPlaylistsFavoritas();
      if (json.isEmpty || json == '[]') return [];
      final lista = jsonDecode(json) as List<dynamic>;
      return lista
          .map((e) => PlaylistDominio.desdeJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ServicioDominioPlaylistConsultas] $e');
      return [];
    }
  }

  /// Todos los tracks de una playlist, ordenados por posición.
  Future<List<TrackDetalle>> getTracks(String playlistId) async {
    try {
      final cache = di.sl<CacheDetalle>();
      final json = await cache.getDetallePlaylist(playlistId);
      if (json == null || json.isEmpty || json == '{}') return [];
      final detalle = DetallePlaylist.desdeJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      return detalle.tracks;
    } catch (e) {
      debugPrint('[ServicioDominioPlaylistConsultas] $e');
      return [];
    }
  }

  /// Carga las stats del usuario (conteos, nivel, progreso).
  Future<EstadisticasUsuario?> getStats() async {
    try {
      final cache = di.sl<CacheDetalle>();
      final json = await cache.getUserStats();
      if (json == null || json.isEmpty || json == '{}') return null;
      return EstadisticasUsuario.desdeJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[ServicioDominioPlaylistConsultas] $e');
      return null;
    }
  }
}
