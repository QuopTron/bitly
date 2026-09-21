// ─────────────────────────────────────────────────────────────
// playlist_propia.dart — Playlist CREADA por el usuario (las `col_*`
// de drift), con su portada y su cantidad de canciones.
//
// Es aparte de las playlists amadas/descargadas a propósito: las
// creadas viven en las tablas locales y son las únicas que se pueden
// editar (nombre, portada, canciones).
// Se conecta con: cache_colecciones (las arma).
// Parte del flujo: Mi Espacio → playlists creadas.
// ─────────────────────────────────────────────────────────────

/// Playlist propia (creada en la app).
class PlaylistPropia {
  final String id;
  final String nombre;

  /// URL o ruta local de la portada. null si no tiene.
  final String? portada;

  /// Canciones que contiene ahora mismo.
  final int canciones;

  const PlaylistPropia({
    required this.id,
    required this.nombre,
    this.portada,
    this.canciones = 0,
  });
}
