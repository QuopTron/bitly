// ─────────────────────────────────────────────────────────────
// reproductor_reporte.dart — PART de cubit_reproductor.dart:
// reportes de scrobbling al backend Go: now playing (Last.fm
// updateNowPlaying + ListenBrainz playing_now) al abrir un track y
// el scrobble final (scrobbleTrack) al completarlo. Ambos son
// fire-and-forget: si el scrobbling no está configurado, Go responde
// error y acá se ignora.
// Se conecta con: reproductor_verificacion.dart (misma library).
// Parte del flujo: reproducción (reporte de plays).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Reportes de scrobbling. Mixin aplicado en CubitReproductor.
mixin ReproductorReporte on ReproductorVerificacion {
  /// Reporta la canción en reproducción a los servicios de scrobbling del
  /// backend Go (Last.fm updateNowPlaying + ListenBrainz playing_now).
  Future<void> _reportNowPlaying(ItemFeed track) async {
    try {
      await di.sl<BackendService>().rpcCall('updateNowPlaying', {
        'trackJSON': jsonEncode({
          'trackName': track.name,
          'artistName': track.artists ?? '',
          'albumName': track.albumName,
        }),
        'lastfmSessionKey': '',
      });
    } catch (_) {}
  }

  /// Envía el scrobble final (track.scrobble + ListenBrainz import) al
  /// backend Go. Fire-and-forget; los errores se ignoran.
  Future<void> _reportScrobble(
    ItemFeed track, {
    required int timestamp,
    required int durationSec,
  }) async {
    try {
      await di.sl<BackendService>().rpcCall('scrobbleTrack', {
        'trackJSON': jsonEncode({
          'trackName': track.name,
          'artistName': track.artists ?? '',
          'albumName': track.albumName,
          'durationMs': durationSec * 1000,
          'timestamp': timestamp,
        }),
        'lastfmSessionKey': '',
      });
    } catch (_) {}
  }
}