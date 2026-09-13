// ─────────────────────────────────────────────────────────────
// reproductor_pagina_build.dart — PART de reproductor_pagina.dart:
// estructura del NowPlaying — provee los cubits en el árbol, arma
// el Scaffold (barra superior + fondo ambiental + columna central
// con portada/video, metadata, seek, controles y velocidad) y
// envuelve todo con el gesto de swipe-down.
// Las piezas (barra, metadata, área, seek, controles, velocidad)
// viven en reproductor_pagina_piezas.dart.
// Se conecta con: reproductor_pagina.dart (misma library) + shared.
// Parte del flujo: reproductor (build del NowPlaying).
// ─────────────────────────────────────────────────────────────

part of 'reproductor_pagina.dart';

/// Construye la página completa del reproductor (NowPlaying).
Widget _buildReproductor(_ReproductorPaginaState st, BuildContext context) {
  final r = Responsive(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final colorFondo =
      esOscuro ? ColoresApp.fondoOscuro : ColoresApp.fondoClaro;

  return MultiBlocProvider(
    providers: [
      BlocProvider<CubitCola>.value(value: sl<CubitCola>()),
      BlocProvider<CubitReproductor>.value(value: sl<CubitReproductor>()),
      BlocProvider<CubitLikes>.value(value: sl<CubitLikes>()),
    ],
    child: BlocBuilder<CubitCola, EstadoCola>(
      builder: (context, cola) {
        if (!cola.tieneActual) {
          return Scaffold(
            backgroundColor: colorFondo,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(child: Text('No track selected')),
          );
        }

        final track = cola.actual!;

        return BlocBuilder<CubitReproductor, EstadoAudioReproductor>(
          // Ignorar ticks de posición (mpv ~25/s): la barra de seek se
          // suscribe sola y el fondo blur/portada no se reconstruye por tick.
          buildWhen: (prev, curr) =>
              prev.duracion != curr.duracion ||
              prev.estadoReproduccion != curr.estadoReproduccion ||
              prev.volumen != curr.volumen ||
              prev.velocidad != curr.velocidad ||
              prev.mensajeError != curr.mensajeError,
          builder: (context, reproductor) {
            final caratulaResuelta =
                context.read<CubitLikes>().caratulaLocalPara(track) ??
                    track.coverUrl;
            final colorBrillo = esOscuro
                ? ColoresApp.verdeBrillante
                : ColoresApp.verdeMedio;
            final activo = esOscuro ? Colors.white : Colors.black;

            final pagina = Scaffold(
              backgroundColor: colorFondo,
              extendBodyBehindAppBar: true,
              appBar: _barraSuperior(
                  st, context, r, track, activo, colorBrillo),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  _FondoAmbiental(
                    coverUrl: caratulaResuelta,
                    esOscuro: esOscuro,
                    colorFondo: colorFondo,
                    mostrarVideo: st._mostrarVideo,
                    videoController: st._videoController,
                  ),
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                      child: Column(
                        children: [
                          const Spacer(flex: 1),
                          _areaPortadaVideo(st, context, r, esOscuro, track,
                              caratulaResuelta),
                          const Spacer(flex: 1),
                          _metadataTrack(context, r, track, activo),
                          const Spacer(flex: 1),
                          _barraSeek(context, r, esOscuro),
                          SizedBox(height: r.spacingM),
                          _filaControles(
                              st, context, r, esOscuro, cola, track),
                          SizedBox(height: r.spacingL),
                          _selectorVelocidad(
                              context, r, esOscuro, reproductor),
                          SizedBox(height: r.spacingXL),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );

            // Swipe hacia abajo para cerrar el reproductor.
            return ValueListenableBuilder<double>(
              valueListenable: st._desplazamiento,
              child: pagina,
              builder: (context, dy, child) {
                final alto = MediaQuery.sizeOf(context).height;
                final acotado = dy < 0 ? 0.0 : dy;
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: (d) => _enArrastre(st, d),
                  onVerticalDragEnd: (d) => _enFinArrastre(st, d),
                  child: Opacity(
                    opacity: _opacidadArrastre(acotado, alto),
                    child: Transform.translate(
                      offset: Offset(0, acotado),
                      child: child,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    ),
  );
}