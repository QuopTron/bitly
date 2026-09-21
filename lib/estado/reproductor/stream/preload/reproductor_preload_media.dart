// ─────────────────────────────────────────────────────────────
// reproductor_preload_media.dart — PART de cubit_reproductor.dart:
// precarga de los media del track actual: letras (LRC) vía el
// backend y video de fondo (local → visualizador directo → descarga
// a temp), más la entrada pública de letras bajo demanda del player
// grande.
// Se conecta con: reproductor_preload.dart (misma library).
// Parte del flujo: player grande (letras + canvas de video).
// ─────────────────────────────────────────────────────────────

part of '../../cubit_reproductor.dart';

/// Precarga de media del track actual. Mixin aplicado en CubitReproductor.
mixin ReproductorPreloadMedia on ReproductorPreload {
  /// Precarga las letras (LRC) de [track]: primero las que ya están
  /// descargadas, y si no hay, las pide al backend Go.
  Future<String?> _preloadLetras(ItemFeed track) async {
    if (!_letrasHabilitadas ||
        track.name.isEmpty ||
        (track.artists ?? '').isEmpty) {
      return null;
    }
    // Una letra sincronizada que ya está en disco no se vuelve a pedir: es la
    // misma que trajo la descarga (o el traspaso de otro aparato) y funciona
    // sin internet. La letra plana se usa solo si la red no da nada mejor.
    final local = _letrasDeDisco(track);
    if (local != null && local.contains('[')) {
      letrasPrecargadas = local;
      return local;
    }
    precargandoLetras = true;
    try {
      final resultado = await di.sl<BackendService>().rpcCall(
        'getLyricsLRCWithSource',
        {
          'track_name': track.name,
          'artist_name': track.artists ?? '',
          'duration_ms': 0,
        },
      );
      final data = _decodeRpcResult(resultado);
      if (data != null) {
        final letras = data['lyrics'] as String? ?? '';
        final instrumental = data['instrumental'] == true;
        letrasPrecargadas =
            (!instrumental && letras.isNotEmpty) ? letras : local;
      } else {
        letrasPrecargadas = local;
      }
    } catch (e) {
      debugPrint('[ReproductorPreloadMedia] $e');
      letrasPrecargadas = local;
    }
    precargandoLetras = false;
    return letrasPrecargadas;
  }

  /// La letra descargada al lado del audio, si existe (o null).
  ///
  /// El nombre es el mismo que escriben las descargas y el traspaso entre
  /// aparatos: `lyrics_<sha1 del id>`. Se prueba el id tal cual y el
  /// normalizado, como hace la limpieza, porque no siempre coinciden.
  String? _letrasDeDisco(ItemFeed track) {
    final carpeta = _rutaDescargas;
    if (carpeta == null || carpeta.isEmpty || track.id.isEmpty) return null;
    final sep = Platform.pathSeparator;
    for (final id in {track.id, normalizarId(track.id)}) {
      if (id.isEmpty) continue;
      final base = '$carpeta$sep${_nombreLetra(id).replaceAll('.lrc', '')}';
      for (final ext in const ['.lrc', '.txt']) {
        try {
          final archivo = File('$base$ext');
          if (!archivo.existsSync()) continue;
          final texto = archivo.readAsStringSync();
          if (texto.trim().isNotEmpty) return texto;
        } catch (e) {
          debugPrint('[ReproductorPreloadMedia] $e');
          // Archivo ilegible: se sigue con la búsqueda en línea.
        }
      }
    }
    return null;
  }

  /// El nombre del archivo de letra (`lyrics_<sha1 del id>.lrc`).
  String _nombreLetra(String id) =>
      'lyrics_${sha1.convert(utf8.encode(id))}.lrc';

  /// Precarga el video de fondo de [track]: local primero, luego la URL
  /// directa de visualizador (progresiva, ~1-2s) y por último la descarga
  /// completa a temp.
  Future<void> _preloadVideo(ItemFeed track) async {
    if (!_videoHabilitado) return;
    precargandoVideo = true;
    try {
      String? videoUrl = _resolveLocalVideoUrl(track);
      videoUrl ??= await resolverUrlVisualizador(track);
      videoUrl ??= await descargarVideoATemp(track);
      urlVideoPrecargado = videoUrl;
      videoPrecargadoListo.value = videoUrl;
    } catch (e) {
      debugPrint('[ReproductorPreloadMedia] $e');
      urlVideoPrecargado = null;
      videoPrecargadoListo.value = null;
    }
    precargandoVideo = false;
  }

  /// Entrada pública del toggle de letras del player grande: busca las LRC
  /// bajo demanda cuando la precarga falló o se saltó. Devuelve las letras
  /// (o null cuando no hay / está deshabilitado).
  Future<String?> obtenerLetrasBajoDemanda(ItemFeed track) async {
    if (!_letrasHabilitadas ||
        track.name.isEmpty ||
        (track.artists ?? '').isEmpty) {
      return null;
    }
    if (letrasPrecargadas != null && letrasPrecargadas!.isNotEmpty) {
      return letrasPrecargadas;
    }
    return _preloadLetras(track);
  }
}
