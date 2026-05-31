/// Funciones utilitarias puras para normalización de datos en bases de datos.
/// Proporciona normalización de ISRC, Spotify ID, y generación de claves
/// de comparación (matchKey, albumKey) para deduplicación y búsqueda
/// difusa sin dependencia de SQLite.
library;

class DatabaseUtils {
  /// Normalize ISRC code for consistent comparison
  /// Removes hyphens, spaces and converts to uppercase
  static String normalizeIsrc(String? value) {
    return (value ?? '').trim().toUpperCase().replaceAll(RegExp(r'[-\s]'), '');
  }

  /// Normalize Spotify ID for consistent comparison
  /// Converts to lowercase and trims whitespace
  static String normalizeSpotifyId(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  /// Create a match key for track+artist combination
  /// Used for fuzzy matching and deduplication
  static String matchKeyFor(String? track, String? artist) {
    final t = (track ?? '').toLowerCase().trim();
    if (t.isEmpty) return '';
    final a = (artist ?? '').toLowerCase().trim();
    return '$t|$a';
  }

  /// Create a canonical key for album+artist combination
  /// Used for album grouping and deduplication
  static String albumKeyFor(String? album, String? artist) {
    final a = (album ?? '').toLowerCase().trim();
    if (a.isEmpty) return '';
    final r = (artist ?? '').toLowerCase().trim();
    return '$a|$r';
  }

  /// Exception para errores de base de datos (Go backend no disponible)
  static Exception dbError() => Exception('Database operation failed - Go backend unavailable');
}