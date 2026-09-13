// PART de reproductor_pagina.dart: barra superior, área portada/video,
// seek bar, fila de controles y selector de velocidad del NowPlaying.

part of 'reproductor_pagina.dart';

Widget _areaPortadaVideo(
  _ReproductorPaginaState st,
  BuildContext context,
  Responsive r,
  bool esOscuro,
  ItemFeed track,
  String? caratulaResuelta,
) {
  return AreaPortadaVideo(
    track: track,
    caratulaResuelta: caratulaResuelta,
    esOscuro: esOscuro,
    mostrarVideo: st._mostrarVideo,
    tieneVideo: st._tieneVideo,
    videoCargando: st._videoCargando,
    videoController: st._videoController,
    onAlternarVideo: () => _alternarVideo(
        st, track, context.read<CubitReproductor>().rutaDescargas),
    onDetenerVideo: () => _detenerVideoParaPortada(st),
  );
}

PreferredSizeWidget _barraSuperior(
  _ReproductorPaginaState st,
  BuildContext context,
  Responsive r,
  ItemFeed track,
  Color activo,
  Color colorBrillo,
) {
  final cola = context.read<CubitCola>().state;
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
      icon:
          Icon(Icons.keyboard_arrow_down_rounded, color: activo, size: 30),
      onPressed: () => Navigator.of(context).pop(),
    ),
    title: Text(
      track.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: activo,
        fontWeight: FontWeight.w600,
        fontSize: r.subtitleSize,
      ),
    ),
    centerTitle: true,
    actions: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(Icons.queue_music_rounded,
                color: activo.withValues(alpha: 0.7)),
            onPressed: () => mostrarModalCola(
              context,
              mostrarVideo: st._mostrarVideo,
              videoController: st._videoController,
            ),
          ),
          if (cola.tracks.length > 1)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: colorBrillo,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${cola.tracks.length}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      IconButton(
        icon: Icon(Icons.share_rounded, color: activo.withValues(alpha: 0.7)),
        onPressed: () {
          final texto = track.albumName != null
              ? '🎵 ${track.name} — ${track.artists ?? ''}\n💿 ${track.albumName}'
              : '🎵 ${track.name} — ${track.artists ?? ''}';
          SharePlus.instance.share(ShareParams(text: texto));
        },
      ),
    ],
  );
}

Widget _barraSeek(
  BuildContext context,
  Responsive r,
  bool esOscuro,
) {
  return BarraSeekReproductor(r: r, esOscuro: esOscuro);
}

Widget _filaControles(
  _ReproductorPaginaState st,
  BuildContext context,
  Responsive r,
  bool esOscuro,
  EstadoCola cola,
  ItemFeed track,
) {
  return FilaControlesReproductor(
    r: r,
    esOscuro: esOscuro,
    cola: cola,
    track: track,
    letrasCargando: st._letrasCargando,
    onAlternarLetras: () => _alternarLetras(st, context),
  );
}

Widget _selectorVelocidad(
  BuildContext context,
  Responsive r,
  bool esOscuro,
  EstadoAudioReproductor reproductor,
) {
  return SelectorVelocidadReproductor(
      r: r, esOscuro: esOscuro, estado: reproductor);
}