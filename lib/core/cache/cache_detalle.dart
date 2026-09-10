// ─────────────────────────────────────────────────────────────
// cache_detalle.dart — Caché JSON read-through para las vistas de
// detalle (álbum, artista, playlist) y estadísticas del usuario.
// Claves: detail:album:{id}, detail:artist:{id},
// detail:playlist:{id}, detail:userStats. TTL: 30 min.
// Se conecta con: base_datos (CacheDao) + vistas de detalle.
// Parte del flujo: detalle de álbum/artista/playlist y stats.
// ─────────────────────────────────────────────────────────────

import '../base_datos/app_database.dart';
import '../base_datos/daos/cache_dao.dart';

/// Caché JSON read-through para detalle + user stats.
class CacheDetalle {
  final CacheDao _dao;
  CacheDetalle(AppDatabase db) : _dao = CacheDao(db);

  /// TTL por defecto en milisegundos (30 minutos).
  static const int ttlMs = 30 * 60 * 1000;

  // ── Detalle de álbum ────────────────────────────────────────

  String _claveAlbum(String id) => 'detail:album:$id';

  Future<String?> getDetalleAlbum(String albumId) =>
      _obtenerSiFresco(_claveAlbum(albumId));

  Future<void> guardarDetalleAlbum(String albumId, String json) =>
      _dao.set(_claveAlbum(albumId), json);

  Future<void> invalidarAlbum(String albumId) =>
      _dao.remove(_claveAlbum(albumId));

  // ── Detalle de artista ──────────────────────────────────────

  String _claveArtista(String id) => 'detail:artist:$id';

  Future<String?> getDetalleArtista(String artistId) =>
      _obtenerSiFresco(_claveArtista(artistId));

  Future<void> guardarDetalleArtista(String artistId, String json) =>
      _dao.set(_claveArtista(artistId), json);

  Future<void> invalidarArtista(String artistId) =>
      _dao.remove(_claveArtista(artistId));

  // ── Detalle de playlist ─────────────────────────────────────

  String _clavePlaylist(String id) => 'detail:playlist:$id';

  Future<String?> getDetallePlaylist(String collectionId) =>
      _obtenerSiFresco(_clavePlaylist(collectionId));

  Future<void> guardarDetallePlaylist(String collectionId, String json) =>
      _dao.set(_clavePlaylist(collectionId), json);

  Future<void> invalidarPlaylist(String collectionId) =>
      _dao.remove(_clavePlaylist(collectionId));

  // ── Stats del usuario (incluye cálculo de nivel) ────────────

  static const String _claveStats = 'detail:userStats';

  Future<String?> getUserStats() => _obtenerSiFresco(_claveStats);

  Future<void> setUserStats(String json) => _dao.set(_claveStats, json);

  Future<void> invalidarUserStats() => _dao.remove(_claveStats);

  /// Cálculo de nivel + progreso del usuario (migrado de Go).
  /// Devuelve un mapa serializable con {level, nextLevel, progress}.
  static Map<String, dynamic> calcularNivel({
    required int totalDescargas,
    required int totalLikes,
    required int totalTiempoReproducidoMs,
  }) {
    const maxNivel = 6;
    final nivel = _nivelCrudo(totalDescargas, totalLikes, totalTiempoReproducidoMs);
    final siguiente = nivel >= maxNivel ? maxNivel : nivel + 1;
    final progreso = _progresoCrudo(totalDescargas, totalLikes, totalTiempoReproducidoMs, nivel);
    return {
      'level': nivel,
      'nextLevel': siguiente,
      'progress': progreso,
    };
  }

  static int _nivelCrudo(int descargas, int likes, int reproduccionMs) {
    if (descargas >= 1000 && likes >= 500 && reproduccionMs >= 360000000) return 6;
    if (descargas >= 500 && likes >= 200 && reproduccionMs >= 180000000) return 5;
    if (descargas >= 200 && likes >= 100 && reproduccionMs >= 72000000) return 4;
    if (descargas >= 100 && likes >= 50 && reproduccionMs >= 36000000) return 3;
    if (descargas >= 50 && likes >= 20 && reproduccionMs >= 10800000) return 2;
    if (descargas >= 10) return 1;
    return 0;
  }

  static double _progresoCrudo(int descargas, int likes, int reproduccionMs, int nivel) {
    // Requisitos por nivel (descargas, likes, reproduccionMs)
    const requisitos = <(int, int, int)>[
      (10, 0, 0),              // Bronze
      (50, 20, 10800000),      // Silver I
      (100, 50, 36000000),     // Silver II
      (200, 100, 72000000),    // Gold I
      (500, 200, 180000000),   // Gold II
      (1000, 500, 360000000),  // Gold III
    ];
    if (nivel >= requisitos.length) return 1.0;

    final (rd, rl, rp) = requisitos[nivel];
    double progreso = 0;
    if (rd > 0) progreso += (descargas < rd ? descargas : rd) / rd * 0.4;
    if (rl > 0) progreso += (likes < rl ? likes : rl) / rl * 0.3;
    if (rp > 0) progreso += (reproduccionMs < rp ? reproduccionMs : rp) / rp * 0.3;
    return progreso > 1.0 ? 1.0 : progreso;
  }

  // ── Operaciones en lote ─────────────────────────────────────

  Future<void> invalidarTodo() => _dao.removeByPrefix('detail:');

  // ── Helpers internos ────────────────────────────────────────

  Future<String?> _obtenerSiFresco(String key) async {
    final ts = await _dao.getTimestamp(key);
    if (ts == null) return null;
    final edad = DateTime.now().millisecondsSinceEpoch - ts;
    if (edad > ttlMs) {
      await _dao.remove(key);
      return null;
    }
    return _dao.get(key);
  }
}