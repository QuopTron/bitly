// ─────────────────────────────────────────────────────────────
// utilidades_id.dart — Normaliza IDs de tracks/álbumes/playlists
// quitando prefijos de proveedor (p.ej. "spotify-web/",
// "spotify:track:", "deezer:playlist:") y pasando a minúsculas.
// Devuelve el [id] crudo si no requiere transformación.
// Se conecta con: caches y cubits (matching entre fuentes).
// Parte del flujo: descargas, likes, deduplicación de items.
// ─────────────────────────────────────────────────────────────

/// Normaliza un ID quitando prefijos de proveedor y pasando a minúsculas.
String normalizarId(String id) {
  int ultimoSlash = id.lastIndexOf('/');
  int ultimoColon = id.lastIndexOf(':');
  int separador = ultimoSlash > ultimoColon ? ultimoSlash : ultimoColon;
  if (separador > 0 && separador < id.length - 1) {
    return id.substring(separador + 1).toLowerCase();
  }
  return id.toLowerCase();
}