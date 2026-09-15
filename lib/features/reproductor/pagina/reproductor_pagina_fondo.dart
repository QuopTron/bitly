// ─────────────────────────────────────────────────────────────
// reproductor_pagina_fondo.dart — PART de reproductor_pagina.dart:
// fondo ambiental del NowPlaying — la carátula desenfocada llena la
// pantalla (o el MISMO video visualizador cuando está activo) con
// un velo de tema (oscuro/claro) y un degradado inferior para que
// los controles sigan legibles. Sin tinte verde de marca.
// Se conecta con: reproductor_pagina.dart (misma library) +
// imagen_portada + perfil de rendimiento + reproductor_video_fondo.
// Parte del flujo: reproductor (fondo ambiental).
// ─────────────────────────────────────────────────────────────


part of 'reproductor_pagina.dart';


/// Fondo de carátula desenfocada (o video) que llena toda la página.
/// En modo Spotify, reemplaza el cover por el color dominante del album.
class _FondoAmbiental extends StatelessWidget {
  final String? coverUrl;
  final bool esOscuro;
  final Color colorFondo;
  final bool mostrarVideo;
  final VideoController? videoController;

  const _FondoAmbiental({
    required this.coverUrl,
    required this.esOscuro,
    required this.colorFondo,
    this.mostrarVideo = false,
    this.videoController,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstiloVisual>(
      valueListenable: sl<ValueNotifier<EstiloVisual>>(),
      builder: (context, estilo, _) {
        return ValueListenableBuilder<PreferenciasEstilo>(
          valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
          builder: (context, prefs, _) {
            final url = coverUrl;
            final perfil = sl<ValueNotifier<PerfilRendimiento>>().value;
            final sigma = perfil.sigmaDesenfoque;
            final spotify =
                estilo == EstiloVisual.spotify && prefs.fondoReproductor;

            return RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Capa 1: cover borroso o video (solo en modo Clásico o video).
                  if (mostrarVideo && videoController != null)
                    TexturaVideoFondo(controller: videoController!)
                  else if (!spotify && url != null && url.isNotEmpty)
                    ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: sigma,
                          sigmaY: sigma,
                        ),
                        child: Transform.scale(
                          scale: 1.25,
                          child: imagenDesdeUrl(
                            url,
                            ajuste: BoxFit.cover,
                            ancho: 512,
                            alto: double.infinity,
                          ),
                        ),
                      ),
                    )
                  else
                    ColoredBox(color: colorFondo),
                  // Capa 2: velo — en Spotify usa color dominante.
                  if (spotify && url != null && url.isNotEmpty)
                    _VeloDinamicoReproductor(
                      coverUrl: url,
                      esOscuro: esOscuro,
                      defaultBg: colorFondo,
                    )
                  else
                    ColoredBox(
                        color: colorFondo.withValues(
                            alpha: esOscuro ? 0.66 : 0.42)),
                  // Capa 3: gradiente inferior.
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          colorFondo.withValues(
                              alpha: esOscuro ? 0.35 : 0.25),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}