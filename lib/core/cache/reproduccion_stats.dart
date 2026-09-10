// ─────────────────────────────────────────────────────────────
// reproduccion_stats.dart — Stats agregadas del usuario calculadas
// de las tablas drift locales (descargas, likes, tiempo, playlists,
// tracks/álbumes/artistas + nivel y progreso).
// Reemplaza el RPC Go GetUserStatsV2.
// Se conecta con: base_datos (DAOs) + CacheDetalle (cálculo de nivel).
// Parte del flujo: Mi Espacio → Estadísticas y perfil.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../base_datos/app_database.dart';
import '../base_datos/daos/collections_dao.dart';
import '../base_datos/daos/content_dao.dart';
import '../base_datos/daos/download_dao.dart';
import '../base_datos/daos/favorites_dao.dart';
import '../base_datos/daos/play_history_dao.dart';
import '../modelos/estadisticas_usuario.dart';
import 'cache_detalle.dart';

/// Stats agregadas del usuario desde drift local.
class ReproduccionStats {
  final DownloadDao _descargas;
  final FavoritesDao _favoritos;
  final PlayHistoryDao _historial;
  final CollectionsDao _colecciones;
  final ContentDao _contenido;

  ReproduccionStats(AppDatabase db)
      : _descargas = DownloadDao(db),
        _favoritos = FavoritesDao(db),
        _historial = PlayHistoryDao(db),
        _colecciones = CollectionsDao(db),
        _contenido = ContentDao(db);

  /// Stats del usuario con totales, nivel y progreso.
  Future<EstadisticasUsuario> getStatsUsuario() async {
    final totalDescargas = await _descargas.getHistoryCount();
    final totalLikes = (await _favoritos.getLovedTracks()).length;
    final totalTiempoMs = await _historial.getTotalPlaybackMs();
    final totalTracksPlaylist = await _colecciones.getCollectionItemsCount();
    final totalTracks = await _contenido.getTrackCount();
    final totalAlbums = await _contenido.getAlbumCount();
    final totalArtistas = await _contenido.getArtistCount();

    // Calcula nivel y progreso (misma lógica que calculateLevel de Go).
    final datosNivel = CacheDetalle.calcularNivel(
      totalDescargas: totalDescargas,
      totalLikes: totalLikes,
      totalTiempoReproducidoMs: totalTiempoMs,
    );

    return EstadisticasUsuario(
      totalDescargas: totalDescargas,
      totalLikes: totalLikes,
      totalTiempoReproducidoMs: totalTiempoMs,
      totalTracksPlaylist: totalTracksPlaylist,
      totalTracks: totalTracks,
      totalAlbums: totalAlbums,
      totalArtistas: totalArtistas,
      nivel: datosNivel['level'] as int? ?? 0,
      siguienteNivel: datosNivel['nextLevel'] as int? ?? 1,
      progreso: datosNivel['progress'] as double? ?? 0.0,
    );
  }

  /// [getStatsUsuario] como JSON string (compatibilidad con BackendService).
  Future<String> getStatsUsuarioJSON() async {
    final stats = await getStatsUsuario();
    return jsonEncode({
      'totalDownloads': stats.totalDescargas,
      'totalLikes': stats.totalLikes,
      'totalPlaybackMs': stats.totalTiempoReproducidoMs,
      'totalPlaylistTracks': stats.totalTracksPlaylist,
      'totalTracks': stats.totalTracks,
      'totalAlbums': stats.totalAlbums,
      'totalArtists': stats.totalArtistas,
      'level': stats.nivel,
      'nextLevel': stats.siguienteNivel,
      'progress': stats.progreso,
    });
  }

  /// Tracks más reproducidos con títulos/artistas reales (del historial
  /// local), listos para renderizar en el perfil. Devuelve:
  /// [{trackId, name, artist, count}]
  Future<List<Map<String, dynamic>>> getTopTracksConNombres(int limit) async {
    final aggs = await _historial.getTop('track', limit: limit);
    final nombres = await _historial.getLatestNames();
    return aggs.map((a) {
      final meta = nombres[a.itemId];
      return {
        'trackId': a.itemId,
        'count': a.playCount ?? 0,
        'name': (meta?.name.isNotEmpty ?? false) ? meta!.name : a.itemId,
        'artist': meta?.artist ?? '',
      };
    }).toList();
  }
}