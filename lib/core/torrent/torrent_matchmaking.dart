// torrent_matchmaking.dart — Matchmaking entre ISRC y torrents FLAC.
//
// Cuando una extensión (Spotify, Deezer, etc.) devuelve un track con ISRC,
// este servicio busca en RED si existe una versión FLAC del mismo ISRC.
// Si la encuentra, devuelve el magnet link para streaming.
//
// Cadena de fallback:
//   1. Buscar por ISRC exacto en RED
//   2. Buscar por título + artista en RED
//   3. Buscar en Internet Archive (ya existe)
//   4. Buscar en YouTube (ya existe, solo visualizer)
//
// Esto permite que Bitly ofrezca FLAC real sin depender de cuentas
// premium en Deezer/Tidal/Qobuz.
import 'dart:async';

/// Resultado del matchmaking.
class TorrentMatch {
  final String? magnetUrl;
  final String? torrentName;
  final String? infoHash;
  final int seeders;
  final int leechers;
  final int size;
  final String source; // "red", "archive", "youtube"
  final bool isLossless;

  const TorrentMatch({
    this.magnetUrl,
    this.torrentName,
    this.infoHash,
    this.seeders = 0,
    this.leechers = 0,
    this.size = 0,
    required this.source,
    this.isLossless = false,
  });
}

/// Servicio de matchmaking.
class TorrentMatchmaking {
  static TorrentMatchmaking? _instance;
  static TorrentMatchmaking get instance =>
      _instance ??= TorrentMatchmaking._();
  TorrentMatchmaking._();

  /// Busca un torrent FLAC por ISRC en RED.
  ///
  /// [isrc] — Código ISRC (ej: "USUM72023904")
  /// [title] — Nombre de la canción (para fallback)
  /// [artist] — Nombre del artista (para fallback)
  Future<TorrentMatch?> findByISRC({
    required String isrc,
    String? title,
    String? artist,
  }) async {
    if (isrc.isEmpty) return null;

    // Intentar por ISRC en RED vía Go backend
    final result = await _searchRED(isrc);
    if (result != null) return result;

    // Fallback: buscar por título + artista
    if (title != null && title.isNotEmpty) {
      final query = artist != null ? '$title $artist' : title;
      final byTitle = await _searchRED(query);
      if (byTitle != null) return byTitle;
    }

    return null;
  }

  /// Busca un torrent FLAC por título en RED.
  Future<TorrentMatch?> findByTitle({
    required String title,
    String? artist,
  }) async {
    final query = artist != null ? '$title $artist' : title;
    return _searchRED(query);
  }

  /// Busca en RED vía el backend Go.
  Future<TorrentMatch?> _searchRED(String query) async {
    try {
      // Llamar al backend Go via RPC
      // TODO: Implementar llamada real al backend
      // final result = await rpcCall('redSearch', {'query': query});
      // if (result != null) {
      //   return TorrentMatch(
      //     magnetUrl: result['magnetUrl'],
      //     torrentName: result['name'],
      //     infoHash: result['infoHash'],
      //     seeders: result['seeders'] ?? 0,
      //     leechers: result['leechers'] ?? 0,
      //     size: result['size'] ?? 0,
      //     source: 'red',
      //     isLossless: true,
      //   );
      // }

      return null; // Stub por ahora
    } catch (e) {
      return null;
    }
  }

  /// Verifica si un torrent tiene suficientes seeders.
  bool isHealthy(TorrentMatch match, {int minSeeders = 3}) {
    return match.seeders >= minSeeders;
  }

  /// Estima el tiempo de descarga basado en seeders y tamaño.
  Duration estimateDownloadTime(TorrentMatch match, {int bandwidthBps = 1024 * 1024}) {
    if (match.size <= 0 || bandwidthBps <= 0) {
      return const Duration(hours: 1);
    }
    final seconds = match.size ~/ bandwidthBps;
    return Duration(seconds: seconds.clamp(10, 3600));
  }
}
