// torrent_service.dart — Servicio de torrents FLAC para Bitly.
//
// Gestiona la descarga y streaming de archivos FLAC vía libtorrent_flutter.
// Se integra con media_kit (mpv) para reproducción: el servicio provee una
// URL HTTP local que media_kit consume directamente.
//
// Flujo:
//   1. Buscar en RED → obtener magnet link
//   2. Agregar magnet a libtorrent_flutter
//   3. Esperar metadata (archivos disponibles)
//   4. Iniciar streaming HTTP → media_kit reproduce mientras descarga
//   5. Cuando termina, el FLAC queda guardado localmente
//
// Soporta: Android, iOS, Windows, macOS, Linux, TV.
// En web no funciona (no hay libtorrent nativo).
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Estado de un torrent.
enum TorrentState {
  idle,
  resolving,    // Buscando peers
  downloading,  // Descargando piezas
  streaming,    // Reproduciendo mientras descarga
  complete,     // Descarga completa
  error,
}

/// Información de un torrent en progreso.
class TorrentInfo {
  final String name;
  final TorrentState state;
  final double progress; // 0.0 - 1.0
  final int downloadRate; // bytes/sec
  final int uploadRate;
  final int numPeers;
  final int numSeeds;
  final int totalDone;
  final int totalWanted;
  final String? streamUrl; // HTTP URL para media_kit
  final List<TorrentFile> files;

  const TorrentInfo({
    required this.name,
    required this.state,
    required this.progress,
    this.downloadRate = 0,
    this.uploadRate = 0,
    this.numPeers = 0,
    this.numSeeds = 0,
    this.totalDone = 0,
    this.totalWanted = 0,
    this.streamUrl,
    this.files = const [],
  });
}

/// Archivo dentro de un torrent.
class TorrentFile {
  final int index;
  final String name;
  final int size;
  final bool isStreamable;

  const TorrentFile({
    required this.index,
    required this.name,
    required this.size,
    this.isStreamable = false,
  });
}

/// Servicio de torrents singleton.
class TorrentService {
  static TorrentService? _instance;
  static TorrentService get instance => _instance ??= TorrentService._();
  TorrentService._();

  bool _initialized = false;
  String? _savePath;
  final Map<String, TorrentInfo> _torrents = {};
  final _controller = StreamController<Map<String, TorrentInfo>>.broadcast();

  /// Stream de actualizaciones de todos los torrents.
  Stream<Map<String, TorrentInfo>> get updates => _controller.stream;

  /// Inicializa el motor de torrents.
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Obtener directorio de guardado
      final dir = await getApplicationDocumentsDirectory();
      _savePath = p.join(dir.path, 'torrents');
      await Directory(_savePath!).create(recursive: true);

      // TODO: Inicializar libtorrent_flutter cuando se agregue la dependencia
      // await LibtorrentFlutter.init(
      //   downloadLimit: 5 * 1024 * 1024, // 5 MB/s
      //   uploadLimit: 1 * 1024 * 1024,   // 1 MB/s
      //   defaultSavePath: _savePath,
      //   fetchTrackers: true,
      // );

      _initialized = true;
      debugPrint('[torrent] Inicializado en $_savePath');
    } catch (e) {
      debugPrint('[torrent] Error inicializando: $e');
    }
  }

  /// Agrega un magnet link y retorna el ID del torrent.
  Future<String?> addMagnet(String magnetUrl, {String? name}) async {
    if (!_initialized) await init();

    try {
      // TODO: Cuando se agregue libtorrent_flutter:
      // final id = LibtorrentFlutter.instance.addMagnet(magnetUrl, _savePath);
      // _torrents[id] = TorrentInfo(
      //   name: name ?? 'Unknown',
      //   state: TorrentState.resolving,
      //   progress: 0,
      // );
      // _controller.add(Map.of(_torrents));
      // return id;

      // Stub por ahora
      final id = 'torrent_${DateTime.now().millisecondsSinceEpoch}';
      _torrents[id] = TorrentInfo(
        name: name ?? 'Unknown',
        state: TorrentState.resolving,
        progress: 0,
      );
      _controller.add(Map.of(_torrents));
      return id;
    } catch (e) {
      debugPrint('[torrent] Error adding magnet: $e');
      return null;
    }
  }

  /// Inicia el streaming de un archivo específico del torrent.
  Future<String?> startStream(String torrentId, {int fileIndex = 0}) async {
    final info = _torrents[torrentId];
    if (info == null) return null;

    try {
      // TODO: Cuando se agregue libtorrent_flutter:
      // final stream = LibtorrentFlutter.instance.startStream(
      //   torrentId,
      //   fileIndex: fileIndex,
      //   maxCacheBytes: 500 * 1024 * 1024, // 500 MB cache
      // );
      // _torrents[torrentId] = TorrentInfo(
      //   name: info.name,
      //   state: TorrentState.streaming,
      //   progress: info.progress,
      //   streamUrl: stream.url,
      //   files: info.files,
      // );
      // _controller.add(Map.of(_torrents));
      // return stream.url;

      // Stub: retorna URL local de ejemplo
      final url = 'http://127.0.0.1:8080/stream/$torrentId';
      _torrents[torrentId] = TorrentInfo(
        name: info.name,
        state: TorrentState.streaming,
        progress: info.progress,
        streamUrl: url,
        files: info.files,
      );
      _controller.add(Map.of(_torrents));
      return url;
    } catch (e) {
      debugPrint('[torrent] Error starting stream: $e');
      return null;
    }
  }

  /// Pausa un torrent.
  void pauseTorrent(String torrentId) {
    // TODO: LibtorrentFlutter.instance.pauseTorrent(torrentId);
  }

  /// Reanuda un torrent.
  void resumeTorrent(String torrentId) {
    // TODO: LibtorrentFlutter.instance.resumeTorrent(torrentId);
  }

  /// Elimina un torrent y sus archivos.
  void removeTorrent(String torrentId, {bool deleteFiles = false}) {
    // TODO: LibtorrentFlutter.instance.removeTorrent(torrentId, deleteFiles: deleteFiles);
    _torrents.remove(torrentId);
    _controller.add(Map.of(_torrents));
  }

  /// Obtiene la info de un torrent.
  TorrentInfo? getTorrent(String torrentId) => _torrents[torrentId];

  /// Obtiene todos los torrents activos.
  Map<String, TorrentInfo> get torrents => Map.of(_torrents);

  /// Limpia torrents completados viejos.
  void cleanup() {
    final toRemove = _torrents.entries
        .where((e) => e.value.state == TorrentState.complete)
        .map((e) => e.key)
        .toList();
    for (final id in toRemove) {
      removeTorrent(id, deleteFiles: false);
    }
  }

  /// Dispose del servicio.
  Future<void> dispose() async {
    // TODO: await LibtorrentFlutter.instance.dispose();
    await _controller.close();
    _torrents.clear();
    _initialized = false;
  }
}
