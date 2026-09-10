// ─────────────────────────────────────────────────────────────
// estadisticas_usuario.dart — Modelo de estadísticas globales del
// usuario (descargas, likes, tiempo reproducido, nivel y progreso).
// Se conecta con: backend_go / caches (stats de Mi Espacio).
// Parte del flujo: Mi Espacio → pestaña estadísticas.
// ─────────────────────────────────────────────────────────────

/// Estadísticas agregadas del usuario con nivel y progreso.
class EstadisticasUsuario {
  final int totalDescargas;
  final int totalLikes;
  final int totalTiempoReproducidoMs;
  final int totalTracksPlaylist;
  final int totalTracks;
  final int totalAlbums;
  final int totalArtistas;
  final int nivel;
  final int siguienteNivel;
  final double progreso;

  const EstadisticasUsuario({
    this.totalDescargas = 0,
    this.totalLikes = 0,
    this.totalTiempoReproducidoMs = 0,
    this.totalTracksPlaylist = 0,
    this.totalTracks = 0,
    this.totalAlbums = 0,
    this.totalArtistas = 0,
    this.nivel = 0,
    this.siguienteNivel = 1,
    this.progreso = 0.0,
  });

  factory EstadisticasUsuario.desdeJson(Map<String, dynamic> json) => EstadisticasUsuario(
    totalDescargas: (json['totalDownloads'] as num?)?.toInt() ?? 0,
    totalLikes: (json['totalLikes'] as num?)?.toInt() ?? 0,
    totalTiempoReproducidoMs: (json['totalPlaybackMs'] as num?)?.toInt() ?? 0,
    totalTracksPlaylist: (json['totalPlaylistTracks'] as num?)?.toInt() ?? 0,
    totalTracks: (json['totalTracks'] as num?)?.toInt() ?? 0,
    totalAlbums: (json['totalAlbums'] as num?)?.toInt() ?? 0,
    totalArtistas: (json['totalArtists'] as num?)?.toInt() ?? 0,
    nivel: (json['level'] as num?)?.toInt() ?? 0,
    siguienteNivel: (json['nextLevel'] as num?)?.toInt() ?? 1,
    progreso: (json['progress'] as num?)?.toDouble() ?? 0.0,
  );
}