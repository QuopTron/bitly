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
  final colorFondo = esOscuro ? ColoresApp.fondoOscuro : ColoresApp.fondoClaro;

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
            body: Center(
              child: Text(AppLocalizations.of(context).reproductor.sinTrack),
            ),
          );
        }

        final track = cola.actual!;

        return BlocBuilder<CubitReproductor, EstadoAudioReproductor>(
          // Ignorar ticks de posición (mpv ~25/s): la barra de seek se
          // suscribe sola y el fondo blur/portada no se reconstruye por tick.
          buildWhen:
              (prev, curr) =>
                  prev.duracion != curr.duracion ||
                  prev.estadoReproduccion != curr.estadoReproduccion ||
                  prev.volumen != curr.volumen ||
                  prev.velocidad != curr.velocidad ||
                  prev.codigoError != curr.codigoError,
          builder: (context, reproductor) {
            final caratulaResuelta =
                context.read<CubitLikes>().caratulaLocalPara(track) ??
                track.coverUrl;
            final colorBrillo =
                esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
            final activo = esOscuro ? Colors.white : Colors.black;

            final pagina = Scaffold(
              backgroundColor: colorFondo,
              extendBodyBehindAppBar: true,
              appBar: _barraSuperior(
                st,
                context,
                r,
                track,
                activo,
                colorBrillo,
              ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  FondoAmbientalReproductor(
                    coverUrl: caratulaResuelta,
                    esOscuro: esOscuro,
                    colorFondo: colorFondo,
                    mostrarVideo: st._mostrarVideo,
                    videoController: st._videoController,
                  ),
                  // La VARIANTE (celular / PC / TV) decide la disposición;
                  // el marco —barra superior, fondo y salida— es el mismo.
                  SafeArea(
                    child: _elegirCuerpoReproductor(
                      _VistaReproductor(
                        st: st,
                        context: context,
                        r: r,
                        esOscuro: esOscuro,
                        track: track,
                        caratula: caratulaResuelta,
                        cola: cola,
                        reproductor: reproductor,
                        activo: activo,
                      ),
                    ),
                  ),
                ],
              ),
            );

            // Arrastrar hacia abajo para cerrar: es del CELULAR. En PC y TV
            // se sale con el botón/tecla de atrás, y un arrastre ahí sería un
            // gesto accidental.
            if (usarLayoutEscritorio(context)) return pagina;

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
