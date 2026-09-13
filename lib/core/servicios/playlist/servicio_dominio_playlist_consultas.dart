// ─────────────────────────────────────────────────────────────
// servicio_dominio_playlist_consultas.dart — PART de
// servicio_dominio_playlist.dart: consultas de playlists (por id,
// detalle con respaldo local/remoto, lista del usuario, tracks y
// stats). Separado para mantener cada archivo dentro del límite.
// Se conecta con: caches (colecciones/detalle/favoritos) + Go.
// Parte del flujo: Mi Espacio → Playlists (lecturas).
// ─────────────────────────────────────────────────────────────

part of 'servicio_dominio_playlist.dart';

/// Consultas de playlists. Mixin combinado en ServicioDominioPlaylist.
mixin ServicioDominioPlaylistConsultas {
  /// Backend Go (lo provee la clase base).
  BackendService get _backend;

  /// Caché de favoritos (lo provee la clase base).
  CacheFavoritos get _fav;

  /// Obtiene una playlist por su ID de colección. null si no existe.
  Future<PlaylistDominio?> getPorId(String id) async {
    final detalle = await getDetalle(id);
    return detalle != null ? _desdeDetalle(detalle) : null;
  }

  /// Obtiene el [DetallePlaylist] completo (con tracks).
  /// Local primero, extensión como respaldo si hay [source].
  Future<DetallePlaylist?> getDetalle(String id, {String? source}) async {
    final cache = di.sl<CacheDetalle>();
    return cargarDetalleConRespaldo(
      id: id,
      source: source ?? '',
      obtenerLocal: (id) => cache.getDetallePlaylist(id),
      obtenerRemoto: (id, src) => _backend.fetchPlaylistDetail(id, src),
      desdeJson: DetallePlaylist.desdeJson,
    );
  }

  /// Todas las playlists del usuario actual.
  Future<List<PlaylistDominio>> getPorUsuario() async {
    try {
      final json = await _fav.getPlaylistsFavoritas();
      if (json.isEmpty || json == '[]') return [];
      final lista = jsonDecode(json) as List<dynamic>;
      return lista
          .map((e) => PlaylistDominio.desdeJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Todos los tracks de una playlist, ordenados por posición.
  Future<List<TrackDetalle>> getTracks(String playlistId) async {
    try {
      final cache = di.sl<CacheDetalle>();
      final json = await cache.getDetallePlaylist(playlistId);
      if (json == null || json.isEmpty || json == '{}') return [];
      final detalle = DetallePlaylist.desdeJson(jsonDecode(json) as Map<String, dynamic>);
      return detalle.tracks;
    } catch (_) {
      return [];
    }
  }

  /// Carga las stats del usuario (conteos, nivel, progreso).
  Future<EstadisticasUsuario?> getStats() async {
    try {
      final cache = di.sl<CacheDetalle>();
      final json = await cache.getUserStats();
      if (json == null || json.isEmpty || json == '{}') return null;
      return EstadisticasUsuario.desdeJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static PlaylistDominio _desdeDetalle(DetallePlaylist d) => PlaylistDominio(
    id: d.id,
    name: d.name,
    trackCount: d.itemCount,
    createdAt: d.createdAt != null ? DateTime.tryParse(d.createdAt!) : null,
    updatedAt: d.updatedAt != null ? DateTime.tryParse(d.updatedAt!) : null,
  );
}