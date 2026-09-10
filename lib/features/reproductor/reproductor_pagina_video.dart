// ─────────────────────────────────────────────────────────────
// reproductor_pagina_video.dart — PART de reproductor_pagina.dart:
// lógica del video visualizador — alternar entre portada y video,
// loop del video (reinicia al terminar), restauración de la sesión
// de video del mismo track al reabrir y detención para volver a la
// portada. Todo el video corre mudo (visualizador puro).
// Se conecta con: reproductor_pagina.dart (misma library) +
// cubit_reproductor + media_kit + conectividad.
// Parte del flujo: reproductor (video visualizador).
// ─────────────────────────────────────────────────────────────

part of 'reproductor_pagina.dart';

/// Alterna entre la portada y el video visualizador del track actual.
Future<void> _alternarVideo(
  _ReproductorPaginaState st,
  ItemFeed track,
  String? dirDescargas,
) async {
  if (st._mostrarVideo) {
    _detenerVideoParaPortada(st);
    return;
  }
  if (st._videoCargando) return;
  st._videoCargando = true;
    st.repintar();
  try {
    String? videoUrl = sl<CubitReproductor>().urlVideoPrecargado;
    videoUrl ??= _resolverVideoLocal(track, dirDescargas);
    if (videoUrl == null) {
      // Sin precarga ni archivo local: buscar bajo demanda solo con red.
      if (!await ServicioConectividad.estaEnLinea()) {
        if (st.mounted) {
          _snackVideo(st.context, 'Sin conexión y sin video descargado');
        }
        return;
      }
      // Ruta rápida: URL directa de visualizador vía InnerTube (progresiva).
      videoUrl = await sl<CubitReproductor>().resolverUrlVisualizador(track);
      // Respaldo: descarga completa a temp (funciona offline después).
      videoUrl ??= await sl<CubitReproductor>().descargarVideoATemp(track);
    }
    if (videoUrl == null || videoUrl.isEmpty) {
      if (st.mounted) {
        _snackVideo(st.context, 'No se pudo obtener el video visualizador');
      }
      return;
    }
    try {
      // El visualizador corre en loop hasta que la canción termine.
      _armarSuscripcionLoopVideo(st);
      await st._videoPlayer.setPlaylistMode(PlaylistMode.loop);
      await st._videoPlayer.open(Media(videoUrl));
      await st._videoPlayer.play();
      // Mudo DESPUÉS de abrir: mpv resetea el volumen en cada open().
      await st._videoPlayer.setVolume(0.0);
      if (!st.mounted) return;
      st._videoLoopArmado = true;
      _SesionVideo.trackKey = '${track.id}|${track.source}';
      _SesionVideo.url = videoUrl;
      _SesionVideo.habilitada = true;
      st._mostrarVideo = true;
      st._tieneVideo = true;
      st.repintar();
    } catch (_) {
      _SesionVideo.habilitada = false;
      _SesionVideo.url = null;
      _SesionVideo.trackKey = null;
      if (st.mounted) {
        _snackVideo(st.context, 'No se pudo reproducir el video visualizador');
      }
    }
  } finally {
    if (st.mounted) st._videoCargando = false;
    st.repintar();
  }
}

/// Listener de loop del visualizador: vuelve al inicio al terminar.
void _armarSuscripcionLoopVideo(_ReproductorPaginaState st) {
  st._videoCompSub ??= st._videoPlayer.stream.completed.listen((_) {
    if (!st._videoLoopArmado || !st.mounted) return;
    st._videoPlayer.seek(Duration.zero);
    st._videoPlayer.play();
  });
}

/// Reabre el reproductor ya en modo video si se minimizó con el visualizador
/// encendido (mismo track). Fire-and-forget: si la URL murió, cae a portada.
Future<void> _restaurarSesionVideo(_ReproductorPaginaState st) async {
  if (!st.mounted ||
      !_SesionVideo.habilitada ||
      _SesionVideo.url == null) {
    return;
  }
  final cola = sl<CubitCola>().state;
  if (!cola.tieneActual) return;
  final clave = '${cola.actual!.id}|${cola.actual!.source}';
  if (_SesionVideo.trackKey != clave) return;
  final url = _SesionVideo.url!;
  st._ultimaClaveCola = clave;
  st._tieneVideo = true;
  st._videoCargando = true;
  st.repintar();
  try {
    _armarSuscripcionLoopVideo(st);
    await st._videoPlayer.setPlaylistMode(PlaylistMode.loop);
    await st._videoPlayer.open(Media(url));
    await st._videoPlayer.play();
    await st._videoPlayer.setVolume(0.0);
    if (!st.mounted) return;
    st._videoLoopArmado = true;
    st._mostrarVideo = true;
    st.repintar();
  } catch (_) {
    _SesionVideo.habilitada = false;
    _SesionVideo.url = null;
    _SesionVideo.trackKey = null;
    if (st.mounted) {
      st._mostrarVideo = false;
      st._tieneVideo = false;
      st.repintar();
    }
  } finally {
    if (st.mounted) st._videoCargando = false;
    st.repintar();
  }
}

/// Detiene el video visualizador y vuelve a la portada.
void _detenerVideoParaPortada(_ReproductorPaginaState st) {
  st._videoLoopArmado = false;
  _SesionVideo.habilitada = false;
  _SesionVideo.url = null;
  _SesionVideo.trackKey = null;
  st._videoPlayer.stop();
  if (st.mounted) st._mostrarVideo = false;
    st.repintar();
}

/// SnackBar flotante con un mensaje del video visualizador.
void _snackVideo(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}