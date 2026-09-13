// ─────────────────────────────────────────────────────────────
// reproductor_pagina_estado.dart — PART de reproductor_pagina.dart:
// estado del reproductor — escucha los cambios reales de track en
// la cola (reinicia video/letras solo cuando la canción cambia),
// reacciona al video precargado listo y calcula la disponibilidad
// del video visualizador (precargado, local descargado o con red).
// Se conecta con: reproductor_pagina.dart (misma library) +
// cubit_cola + cubit_reproductor + conectividad.
// Parte del flujo: reproductor (estado del NowPlaying).
// ─────────────────────────────────────────────────────────────

part of 'reproductor_pagina.dart';

/// Escucha la cola: al cambiar la canción actual reinicia video/letras.
void _escucharCambiosCola(_ReproductorPaginaState st) {
  final cola = sl<CubitCola>();
  cola.stream.listen((estadoCola) {
    final clave = estadoCola.tieneActual
        ? '${estadoCola.actual!.id}|${estadoCola.actual!.source}'
        : null;
    if (clave == st._ultimaClaveCola) return;
    st._ultimaClaveCola = clave;
    st._tieneVideo = false;
    st._videoLoopArmado = false;
    _SesionVideo.habilitada = false;
    _SesionVideo.url = null;
    _SesionVideo.trackKey = null;
    if (st._mostrarVideo) {
      st._videoPlayer.stop();
      st._mostrarVideo = false;
    st.repintar();
    }
    st._letrasCargando = false;
    st._videoTrackId = null;
    _refrescarDisponibilidadVideo(st);
  });
}

/// Cuando el video de fondo termina de precargar, refleja la disponibilidad.
void _enVideoListo(_ReproductorPaginaState st) {
  if (!st.mounted) return;
  final cubit = sl<CubitReproductor>();
  final cola = sl<CubitCola>().state;
  if (!cola.tieneActual) return;
  final track = cola.actual!;
  if (st._videoTrackId != track.id) {
    st._videoTrackId = track.id;
    st._tieneVideo = false;
    st._mostrarVideo = false;
  }
  final url = cubit.videoPrecargadoListo.value;
  final listo = url != null && url.isNotEmpty;
  if (listo != st._tieneVideo) {
    st._tieneVideo = listo;
    st.repintar();
  }
  _refrescarDisponibilidadVideo(st);
}

/// Disponibilidad inteligente: video precargado, descargado o con red.
Future<void> _refrescarDisponibilidadVideo(_ReproductorPaginaState st) async {
  if (!st.mounted) return;
  final cubit = sl<CubitReproductor>();
  final cola = sl<CubitCola>().state;
  if (!cola.tieneActual) return;
  final track = cola.actual!;
  final claveChequeo = '${track.id}|${track.source}';
  final precargado = cubit.videoPrecargadoListo.value;
  final listo = precargado != null && precargado.isNotEmpty;
  final descargado = _resolverVideoLocal(track, cubit.rutaDescargas) != null;
  if (listo || descargado) {
    if (st.mounted && !st._tieneVideo) {
      st._tieneVideo = true;
    st.repintar();
    }
    return;
  }
  final enLinea = await ServicioConectividad.estaEnLinea();
  if (!st.mounted) return;
  final actual = sl<CubitCola>().state;
  if (!actual.tieneActual ||
      '${actual.actual!.id}|${actual.actual!.source}' != claveChequeo) {
    return; // el track cambió mientras esperábamos el chequeo de red
  }
  if (st._tieneVideo != enLinea) {
    st._tieneVideo = enLinea;
    st.repintar();
  }
}

/// Resuelve una URL de video local para [track] (por id o nombre-artista).
String? _resolverVideoLocal(ItemFeed track, String? dirDescargas) {
  if (dirDescargas == null) return null;
  final exts = ['mp4', 'webm', 'mkv', 'avi'];
  for (final ext in exts) {
    final ruta = '$dirDescargas\\${track.id}.$ext';
    if (File(ruta).existsSync()) return 'file://${ruta.replaceAll('\\', '/')}';
  }
  if (track.name.isNotEmpty &&
      track.artists != null &&
      track.artists!.isNotEmpty) {
    const invalidos = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    String sanear(String s) {
      var r = s;
      for (final ch in invalidos) {
        r = r.replaceAll(ch, '_');
      }
      r = r.replaceAll(RegExp(r'[. ]+$'), '');
      return r.isEmpty ? 'unknown' : r;
    }

    final tallo = '${sanear(track.artists!)} - ${sanear(track.name)}';
    for (final ext in exts) {
      final ruta = '$dirDescargas\\$tallo.$ext';
      if (File(ruta).existsSync()) {
        return 'file://${ruta.replaceAll('\\', '/')}';
      }
    }
  }
  return null;
}