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
    final url = coverUrl;
    final perfil = sl<ValueNotifier<PerfilRendimiento>>().value;
    final sigma = perfil.sigmaDesenfoque;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (mostrarVideo && videoController != null)
            // El video visualizador ES el fondo (sin blur por frame — el velo
            // de tema mantiene la UI legible). Refleja la MISMA textura que la
            // portada cuadrada para una sola salida nativa en dos lugares.
            TexturaVideoFondo(controller: videoController!)
          else if (url != null && url.isNotEmpty) ...[
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
                    // Decode acotado — el blur disimula el detalle.
                    ancho: 512,
                    alto: double.infinity,
                  ),
                ),
              ),
            ),
          ] else
            ColoredBox(color: colorFondo),
          // Velo de tema — mantiene la página realmente oscura / clara.
          ColoredBox(
              color: colorFondo.withValues(alpha: esOscuro ? 0.66 : 0.42)),
          // Dim extra abajo para que seek bar + controles sigan legibles.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  colorFondo.withValues(alpha: esOscuro ? 0.35 : 0.25),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}