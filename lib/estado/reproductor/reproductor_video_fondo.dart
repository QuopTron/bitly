// ─────────────────────────────────────────────────────────────
// reproductor_video_fondo.dart — PART de cubit_reproductor.dart:
// video de fondo del reproductor: resolución de archivos de video
// locales, visualizador directo vía InnerTube del backend Go, caché
// de videos descargados y descarga a temp con respaldo. El
// sanitizador de nombres y la descarga de URLs crudas viven en
// reproductor_video_descarga.dart.
// Se conecta con: reproductor_video_descarga.dart (misma library).
// Parte del flujo: player grande (canvas de video de fondo).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Video de fondo. Mixin aplicado en CubitReproductor.
mixin ReproductorVideoFondo on ReproductorVideoDescarga {
  /// Resuelve la ruta local de un video de fondo para [track], o null.
  String? _resolveLocalVideoUrl(ItemFeed track) {
    if (_rutaDescargas == null) return null;
    final extsVideo = ['mp4', 'webm', 'mkv', 'avi'];
    for (final ext in extsVideo) {
      final ruta = '$_rutaDescargas\\${track.id}.$ext';
      if (File(ruta).existsSync()) {
        return 'file://${ruta.replaceAll('\\', '/')}';
      }
    }
    if (track.name.isNotEmpty && (track.artists ?? '').isNotEmpty) {
      final stem = '${_sanitizarNombre(track.artists!)} - '
          '${_sanitizarNombre(track.name)}';
      for (final ext in extsVideo) {
        final ruta = '$_rutaDescargas\\$stem.$ext';
        if (File(ruta).existsSync()) {
          return 'file://${ruta.replaceAll('\\', '/')}';
        }
      }
    }
    return null;
  }

  /// Busca un video de fondo ya descargado en el caché de stream.
  String? _videoCacheadoExistente(ItemFeed track, Directory cacheDir) {
    final sep = Platform.pathSeparator;
    final candidatos = <String>['${cacheDir.path}$sep${track.id}.mp4'];
    if (track.name.isNotEmpty && (track.artists ?? '').isNotEmpty) {
      candidatos.add(
        '${cacheDir.path}$sep${_sanitizarNombre(track.artists!)} - '
        '${_sanitizarNombre(track.name)}.mp4',
      );
    }
    for (final c in candidatos) {
      if (File(c).existsSync()) return 'file://${c.replaceAll('\\', '/')}';
    }
    return null;
  }

  /// Resuelve una URL DIRECTA de visualizador para [track] vía la ruta
  /// InnerTube del backend Go (sin descargar el archivo completo, sin
  /// yt-dlp), para que el player grande arranque el visualizador en ~1-2s.
  /// Devuelve null cuando no se pudo resolver (el llamador cae a un video
  /// ya descargado y luego al pipeline de descarga completa).
  Future<String?> resolverUrlVisualizador(ItemFeed track) async {
    try {
      final estrategia = <String, dynamic>{
        'type': 'video',
        'track_id': track.id,
        'item_id': '${track.id}_video',
        'track_title': track.name,
        'artist_name': track.artists ?? '',
        'source': track.source ?? '',
        'isrc': track.isrc ?? '',
        'quality': _calidadVideo,
        'duration_ms': track.durationMs ?? 0,
        'spotify_id': track.spotifyId ?? '',
        'deezer_id': track.deezerId ?? '',
        'tidal_id': track.tidalId ?? '',
        'qobuz_id': track.qobuzId ?? '',
      };
      final res = await di.sl<BackendService>().rpcCall('resolveVisualizerUrl', {
        'request': jsonEncode(estrategia),
      });
      final data = _decodeRpcResult(res);
      final url = (data?['url'] ?? '').toString();
      if (url.isEmpty) return null;
      // Copia de trabajo para offline: el visualizador vive en el caché de
      // stream y reusarlo después evita otra descarga completa.
      try {
        final appCacheDir = await getApplicationCacheDirectory();
        final cacheDir = Directory(
          '${appCacheDir.path}${Platform.pathSeparator}stream_cache',
        );
        if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
        final fp = '${cacheDir.path}${Platform.pathSeparator}${track.id}.mp4';
        if (!await File(fp).exists()) {
          unawaited(_downloadUrlAArchivo(url, fp));
        }
      } catch (_) {}
      return url;
    } catch (_) {
      return null;
    }
  }

  /// Descarga el video de fondo de [track] al caché de la app (stream_cache)
  /// vía el backend Go y devuelve una URL file:// reproducible. El video es
  /// una feature visual separada (cover ↔ video toggle), nunca parte de la
  /// resolución del stream de audio.
  Future<String?> descargarVideoATemp(ItemFeed track) async {
    try {
      final appCacheDir = await getApplicationCacheDirectory();
      final cacheDir = Directory(
        '${appCacheDir.path}${Platform.pathSeparator}stream_cache',
      );
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

      final existente = _videoCacheadoExistente(track, cacheDir);
      if (existente != null) return existente;

      final estrategia = <String, dynamic>{
        'type': 'video',
        'track_id': track.id,
        'item_id': '${track.id}_video',
        'track_title': track.name,
        'artist_name': track.artists ?? '',
        'source': track.source ?? '',
        'isrc': track.isrc ?? '',
        'quality': _calidadVideo,
        'output_dir': cacheDir.path,
      };
      final res = await di.sl<BackendService>().downloadByStrategy(
        jsonEncode(estrategia),
      );
      final data = _decodeRpcResult(res);
      final fp = (data?['filePath'] ?? data?['file_path'] ?? '').toString();
      if (fp.isEmpty || !await File(fp).exists()) return null;
      return 'file://${fp.replaceAll('\\', '/')}';
    } catch (_) {
      return null;
    }
  }
}