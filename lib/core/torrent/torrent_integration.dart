// torrent_integration.dart — Integración del torrent con el reproductor.
//
// Cuando el backend Go devuelve un "stream URL" que es un magnet link
// (comienza con "magnet:"), este módulo lo intercepta y:
//   1. Agrega el torrent a libtorrent_flutter
//   2. Espera a que las primeras piezas estén disponibles
//   3. Retorna una URL HTTP local que media_kit puede reproducir
//
// Para URLs HTTP normales (no magnet), pasa el URL directamente.
import 'dart:async';

import 'torrent_service.dart';
import 'torrent_matchmaking.dart';

/// Resuelve un stream URL: si es magnet → torrent, si es HTTP → directo.
class TorrentStreamResolver {
  static TorrentStreamResolver? _instance;
  static TorrentStreamResolver get instance =>
      _instance ??= TorrentStreamResolver._();
  TorrentStreamResolver._();

  final _service = TorrentService.instance;
  final _matchmaking = TorrentMatchmaking.instance;

  /// Resuelve un stream URL para el reproductor.
  ///
  /// Si [url] es un magnet link, inicia el torrent y retorna la URL HTTP.
  /// Si [url] es HTTP/HTTPS, retorna el URL directo.
  /// Si [url] es nulo, busca por ISRC en RED.
  Future<String?> resolve({
    String? url,
    String? isrc,
    String? title,
    String? artist,
  }) async {
    // 1. Si ya hay una URL HTTP, usarla directo
    if (url != null && !url.startsWith('magnet:')) {
      return url;
    }

    // 2. Si es un magnet link, iniciar torrent
    if (url != null && url.startsWith('magnet:')) {
      return _resolveMagnet(url, title: title);
    }

    // 3. Si hay ISRC, buscar en RED
    if (isrc != null && isrc.isNotEmpty) {
      final match = await _matchmaking.findByISRC(
        isrc: isrc,
        title: title,
        artist: artist,
      );
      if (match?.magnetUrl != null) {
        return _resolveMagnet(match!.magnetUrl!, title: title);
      }
    }

    // 4. Si hay título, buscar por nombre
    if (title != null && title.isNotEmpty) {
      final match = await _matchmaking.findByTitle(
        title: title,
        artist: artist,
      );
      if (match?.magnetUrl != null) {
        return _resolveMagnet(match!.magnetUrl!, title: title);
      }
    }

    return null;
  }

  /// Resuelve un magnet link a una URL HTTP de streaming.
  Future<String?> _resolveMagnet(String magnetUrl, {String? title}) async {
    // Agregar torrent
    final torrentId = await _service.addMagnet(magnetUrl, name: title);
    if (torrentId == null) return null;

    // Esperar metadata (archivos disponibles)
    final completer = Completer<String?>();
    late StreamSubscription sub;

    sub = _service.updates.listen((torrents) {
      final info = torrents[torrentId];
      if (info == null) return;

      // Cuando hay archivos, iniciar streaming
      if (info.state == TorrentState.resolving && info.files.isNotEmpty) {
        _service.startStream(torrentId).then((streamUrl) {
          if (!completer.isCompleted) {
            completer.complete(streamUrl);
          }
        });
      }

      // Si ya está streaming, usar la URL
      if (info.streamUrl != null && !completer.isCompleted) {
        completer.complete(info.streamUrl);
      }

      // Si hay error
      if (info.state == TorrentState.error && !completer.isCompleted) {
        completer.complete(null);
      }
    });

    // Timeout de 30 segundos
    Future.delayed(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.complete(null);
        sub.cancel();
      }
    });

    final result = await completer.future;
    await sub.cancel();
    return result;
  }

  /// Verifica si un URL es un magnet link.
  static bool isMagnet(String url) => url.startsWith('magnet:');

  /// Verifica si un URL necesita resolución de torrent.
  static bool needsTorrentResolution(String? url) {
    if (url == null) return false;
    return url.startsWith('magnet:') || url.isEmpty;
  }
}
