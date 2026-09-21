// ─────────────────────────────────────────────────────────────
// content_dao_biblioteca.dart — PART de content_dao.dart: listados
// completos de la biblioteca local (álbumes, canciones y artistas)
// con nombre y carátula, para que la UI arme un índice por ID y
// ninguna tarjeta quede sin portada ni sin título.
// Se conecta con: content_dao.dart (misma library) + tablas locales.
// Parte del flujo: Mi Espacio (carátulas y nombres de respaldo).
// ─────────────────────────────────────────────────────────────

part of 'content_dao.dart';

/// Consultas de biblioteca completa. Extensión sobre [ContentDao] para
/// mantener cada archivo dentro del límite de líneas del proyecto.
extension ContentDaoBiblioteca on ContentDao {
  /// Todos los álbumes guardados (id, nombre y carátula).
  Future<List<Album>> getAlbumesBiblioteca() => select(albums).get();

  /// Todas las canciones guardadas (id, nombre y carátula).
  Future<List<Track>> getTracksBiblioteca() => select(tracks).get();

  /// Todos los artistas guardados (id, nombre e imagen).
  Future<List<Artist>> getArtistasBiblioteca() => select(artists).get();
}
