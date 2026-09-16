// ─────────────────────────────────────────────────────────────
// detalle_escucha.dart — Arma el detalle de las estadísticas de
// escucha desde la base local: por cada tipo (canciones, álbumes,
// artistas, playlists) devuelve las filas con reproducciones, minutos
// y fecha de la última vez, listas para filtrar y ordenar.
//
// De dónde salen los datos: de las MISMAS tablas que ya usa el perfil
// (PlayAggregates para los contadores y PlayHistory para el tiempo y la
// fecha). No hay un segundo contador: si el detalle y el resumen no
// coinciden, es un bug, no dos fuentes.
//
// Los minutos solo se pueden calcular en canciones (el historial guarda
// la duración por canción); para álbumes/artistas/playlists se dejan en
// 0 en vez de inventarlos.
//
// Se conecta con: app_database (DAOs) + filtro_escucha (filtra/ordena) +
// settings_estadisticas_detalle (lo pinta).
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

import '../../base_datos/app_database.dart';
import '../../base_datos/daos/play_history_dao.dart';
import 'filtro_escucha.dart';

/// Detalle de escucha calculado desde drift local.
class DetalleEscucha {
  final PlayHistoryDao _historial;

  DetalleEscucha(AppDatabase db) : _historial = PlayHistoryDao(db);

  /// Filas de un tipo, con nombre/artista resueltos y minutos acumulados.
  ///
  /// [limit] acota cuántos contadores se leen (el usuario ve el top, no miles
  /// de filas: leer todo era el costo que hacía lento este modal).
  Future<List<FilaEscucha>> filas(TipoEscucha tipo, {int limit = 200}) async {
    final agregados = await _historial.getTop(tipo.clave, limit: limit);
    if (agregados.isEmpty) return const [];

    final nombres = await _historial.getLatestNames();
    final minutos = tipo == TipoEscucha.canciones ? await _minutosPorItem() : {};

    return agregados.map((a) {
      final datos = nombres[a.itemId];
      return FilaEscucha(
        id: a.itemId,
        nombre: (datos?.name ?? '').trim().isEmpty
            ? a.itemId
            : datos!.name,
        artista: datos?.artist ?? '',
        reproducciones: a.playCount ?? 0,
        minutos: minutos[a.itemId] ?? 0,
        ultimaVez: a.lastPlayedAt,
      );
    }).toList();
  }

  /// Minutos escuchados por ítem, sumando la duración real de cada
  /// reproducción del historial. Se lee acotado: el historial puede tener
  /// miles de filas y esto alimenta un modal, no un informe.
  Future<Map<String, int>> _minutosPorItem() async {
    final recientes = await _historial.getRecent(limit: 2000);
    final acumulado = <String, int>{};
    for (final r in recientes) {
      final id = r.trackId;
      if (id == null || id.isEmpty) continue;
      acumulado[id] = (acumulado[id] ?? 0) + (r.durationMs ?? 0);
    }
    return acumulado.map((k, ms) => MapEntry(k, ms ~/ 60000));
  }
}
