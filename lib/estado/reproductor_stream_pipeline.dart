// ─────────────────────────────────────────────────────────────
// reproductor_stream_pipeline.dart — PART de cubit_reproductor.dart:
// pipeline de resolución de stream: la llamada RPC getStreamPackage
// al backend Go (con calidad efectiva según red, ids cross-proveedor
// y respaldo de descarga opcional) y el decrypt de archivos DRM
// (p.ej. FLAC de amazon) vía ffmpeg-kit a un archivo reproducible.
// Se conecta con: reproductor_stream_proxy.dart (misma library).
// Parte del flujo: reproducción (resolver URL de streaming).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Pipeline de resolución. Mixin aplicado en CubitReproductor.
mixin ReproductorStreamPipeline on ReproductorStreamProxy {
  /// Llama getStreamPackage al backend y devuelve la URL/archivo resuelto.
  Future<String?> _resolveStreamUrlInner(
    ItemFeed track, {
    bool esPreload = false,
    bool conRespaldo = false,
  }) async {
    final name = track.name.trim();
    if (name.isEmpty) return null;
    try {
      final resultado = await di.sl<BackendService>().rpcCall('getStreamPackage', {
        'preferredProvider': track.source ?? '',
        'trackID': track.id,
        'quality': await _calidadStreamEfectiva(_calidadAudio),
        'fetchLyrics': 'false',
        'trackName': name,
        'artistName': track.artists ?? '',
        'isrc': track.isrc ?? '',
        'durationMs': track.durationMs,
        // Ids cross-proveedor (tracks de detalle) para que el backend resuelva
        // vía CheckAvailability en cualquier proveedor en vez de una búsqueda
        // lenta por nombre.
        'spotifyId': track.spotifyId ?? '',
        'deezerId': track.deezerId ?? '',
        'tidalId': track.tidalId ?? '',
        'qobuzId': track.qobuzId ?? '',
        // Los probes de fondo saltan el respaldo de descarga (sin descargas de
        // audio completas en segundo plano); taps reales y el preload del
        // siguiente inmediato lo permiten.
        'allowFallback': !esPreload || conRespaldo,
        // Un tap con respaldo puede descargar un FLAC completo (30-90s en
        // redes lentas) tras recorrer proveedores: ventana cómoda.
      }, const Duration(seconds: 180));
      final data = _decodeRpcResult(resultado);
      if (data != null) {
        // El backend descargó un archivo cifrado/DRM real (p.ej. FLAC de
        // amazon) que solo necesita ffmpeg para desencriptar; sin CLI ffmpeg
        // en Android, desencriptamos aquí vía ffmpeg-kit.
        if (data['needsDecryption'] == true) {
          final dec = await _decryptParaPlayback(data, track);
          if (dec != null && dec.isNotEmpty) return dec;
          return null;
        }
        final url = (data['audioUrl'] ?? '').toString();
        if (url.isNotEmpty) return url;
        final err = (data['error'] ?? '').toString();
        // El stream se resuelve ANTES de fallar el playback. El modal de
        // verificación Cloudflare se abre proactivamente en
        // _ensureSesionParaFuente (llamado desde _openTrack), así un tap
        // válido nunca llega acá sin verificar.
        if (err.isNotEmpty && !esPreload) {
          _ultimoErrorStream = err;
          _ultimoTipoErrorStream = (data['errorType'] ?? '').toString();
          _ultimoServicioStream = (data['service'] ?? '').toString();
        }
      }
      return null;
    } catch (e) {
      if (!esPreload) {
        _ultimoErrorStream = e.toString();
      }
      return null;
    }
  }

  /// Desencripta un archivo de stream cifrado/DRM devuelto por el backend vía
  /// ffmpeg-kit, escribe el archivo reproducible en el caché de stream, y
  /// devuelve una URL `file://` (o null si falló).
  Future<String?> _decryptParaPlayback(
    Map<String, dynamic> data,
    ItemFeed track,
  ) async {
    final src = (data['filePath'] ?? '').toString();
    final clave = (data['decryptionKey'] ?? '').toString();
    if (src.isEmpty || clave.isEmpty) return null;

    final normalizado = normalizarId(track.id);
    final cacheDir = await _getStreamCacheDir();
    final resultado = await desencriptarArchivoMovKey(
      rutaOrigen: src,
      clave: clave,
      formatoEntrada: (data['inputFormat'] ?? '').toString(),
      extensionSalida: (data['outputExtension'] ?? '').toString(),
      directorioSalida: cacheDir.path,
      nombreBaseSalida: normalizado,
    );
    if (resultado.exito && resultado.rutaArchivo != null) {
      _archivosTempStream.add(normalizado);
      return 'file://${resultado.rutaArchivo!.replaceAll('\\', '/')}';
    }
    return null;
  }
}