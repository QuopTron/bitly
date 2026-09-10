// ─────────────────────────────────────────────────────────────
// reproduccion_cache.dart — Caché local de reproducción: registra
// plays en drift (historial + agregados + contador diario) y calcula
// el nivel de escucha con su límite diario.
// Reemplaza los RPCs Go: logPlayV2JSON, getRecentPlaysV2JSON,
// getPlayStatsV2JSON y getListeningLevelV2JSON.
// Se conecta con: base_datos (PlayHistoryDao, PremiumDao).
// Parte del flujo: reproducción (reporte de plays) y límites free.
// ─────────────────────────────────────────────────────────────

import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../base_datos/app_database.dart';
import '../base_datos/daos/play_history_dao.dart';
import '../base_datos/daos/premium_dao.dart';

final _log = Logger();

/// Caché local de historial, agregados, plays diarios y nivel de escucha.
class ReproduccionCache {
  final PlayHistoryDao _historial;
  final PremiumDao _premium;

  ReproduccionCache(AppDatabase db)
      : _historial = PlayHistoryDao(db),
        _premium = PremiumDao(db);

  /// Registra un play en las tablas drift locales:
  /// 1. Inserta en `play_history`
  /// 2. Incrementa `play_aggregates` del track
  /// 3. Incrementa `user_daily_plays` de hoy
  Future<void> registrarPlay({
    required String trackId,
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationMs,
    int? percentage,
  }) async {
    final ahora = DateTime.now();

    await _historial.logPlay(
      PlayHistoryCompanion(
        trackId: Value(trackId),
        trackName: Value(trackName),
        artistName: Value(artistName),
        albumName: Value(albumName ?? ''),
        playedAt: Value(ahora),
        durationMs: Value(durationMs),
        percentage: Value(percentage),
      ),
    );

    await _historial.incrementPlayCount(trackId, 'track');

    final hoy = ahora.toUtc().toIso8601String().substring(0, 10);
    await _premium.incrementDailyPlayCount(hoy);
  }

  /// Plays recientes desde play_history local.
  Future<List<PlayHistoryData>> getPlaysRecientes({int limit = 50}) =>
      _historial.getRecent(limit: limit);

  /// Top stats de plays por tipo (track, album, artist).
  Future<List<PlayAggregate>> getStatsPlays(String type, {int limit = 20}) =>
      _historial.getTop(type, limit: limit);

  /// Calcula el nivel de escucha y el límite diario con datos locales.
  ///
  /// Devuelve un mapa con la misma forma que la respuesta vieja de Go:
  /// {level, totalPlays, dailyLimit, playsToday, playsRemaining, blocked}
  Future<Map<String, dynamic>> getNivelEscucha() async {
    final totalPlays = await _historial.sumPlayCounts('track');

    final hoy = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final playsHoy = await _premium.getDailyPlayCount(hoy);

    final premium = await _premium.getPremium();
    final esPremium = premium != null && premium.tier != 'free';

    String nivel = 'free';
    int limiteDiario = 50;

    if (totalPlays >= 10000) {
      nivel = 'legend';
      limiteDiario = 999999;
    } else if (totalPlays >= 5000) {
      nivel = 'gold';
      limiteDiario = 300;
    } else if (totalPlays >= 1000) {
      nivel = 'silver';
      limiteDiario = 200;
    } else if (totalPlays >= 100) {
      nivel = 'bronze';
      limiteDiario = 100;
    }

    if (esPremium) {
      if (premium.tier == 'lifetime') {
        nivel = 'legend';
        limiteDiario = 999999;
      } else {
        limiteDiario = 500;
        if (totalPlays >= 5000) {
          nivel = 'legend';
          limiteDiario = 999999;
        } else if (totalPlays >= 1000) {
          nivel = 'gold';
        } else {
          nivel = 'premium';
        }
      }
    }

    _log.i(
      '[ReproduccionCache] nivel=$nivel totalPlays=$totalPlays limiteDiario=$limiteDiario playsHoy=$playsHoy esPremium=$esPremium',
    );

    return {
      'level': nivel,
      'totalPlays': totalPlays,
      'dailyLimit': limiteDiario,
      'playsToday': playsHoy,
      'playsRemaining': limiteDiario - playsHoy,
      'blocked': playsHoy >= limiteDiario,
    };
  }

  /// Stats de reproducción para el perfil de ajustes, calculadas de las
  /// tablas drift LOCALES (el tracker en memoria de Go está vacío en el
  /// dispositivo, así que el viejo RPC getPlaybackStats siempre daba ceros).
  Future<Map<String, dynamic>> getStatsPerfil() async {
    final nivel = await getNivelEscucha();
    final tracksUnicos = await _historial.countAggregates('track');
    final artistasUnicos = await _historial.getDistinctArtistsCount();
    final duracionTotal = await _historial.getTotalPlaybackMs();
    return {
      'totalPlays': nivel['totalPlays'] ?? 0,
      'uniqueTracks': tracksUnicos,
      'uniqueArtists': artistasUnicos,
      'totalDuration': duracionTotal,
      'playsToday': nivel['playsToday'] ?? 0,
      'dailyLimit': nivel['dailyLimit'] ?? 50,
      'playsRemaining': nivel['playsRemaining'] ?? 0,
      'level': nivel['level'] ?? 'free',
      'blocked': nivel['blocked'] ?? false,
    };
  }
}