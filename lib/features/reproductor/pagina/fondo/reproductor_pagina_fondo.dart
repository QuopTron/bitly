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

part of '../base/reproductor_pagina.dart';

/// Fondo de carátula desenfocada (o video) que llena toda la página.
/// Con el estilo con cover, el color dominante del album reemplaza al cover.
///
/// Es PÚBLICA a propósito: el test del control de intensidad la monta tal
/// cual para medir el fondo del reproductor, no una copia de su cuenta.
class FondoAmbientalReproductor extends StatelessWidget {
  final String? coverUrl;
  final bool esOscuro;
  final Color colorFondo;
  final bool mostrarVideo;
  final VideoController? videoController;

  const FondoAmbientalReproductor({
    super.key,
    required this.coverUrl,
    required this.esOscuro,
    required this.colorFondo,
    this.mostrarVideo = false,
    this.videoController,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PreferenciasEstilo>(
      valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
      builder: (context, prefs, _) {
        final url = coverUrl;
        final perfil = sl<ValueNotifier<PerfilRendimiento>>().value;
        final sigma = perfil.sigmaDesenfoque;
        // Intensidad del cover: 0 = cover borroso con velo del tema
        // (lo de siempre), 1 = sólo el color dominante. En el medio se
        // cruzan las capas 1:1: cada punto porcentual del control vale lo
        // mismo de punta a punta.
        final v = prefs.fondoReproductor;
        // Y la carátula se va desenfocando con la intensidad hasta disolverse
        // en el color del cover (con su tope propio, ver estilo_helper).
        final sigmaFondo = EstiloHelper.sigmaPorNivel(sigma, v);
        final velo = EstiloHelper.mezclar(
          esOscuro ? 0.66 : 0.42,
          esOscuro ? 0.34 : 0.22,
          v,
        );

        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Capa 0: base opaca.
              ColoredBox(color: colorFondo),
              // Capa 1: video del track, o el cover borroso si no hay
              // video. El cover se apaga con la intensidad.
              if (mostrarVideo && videoController != null)
                TexturaVideoFondo(controller: videoController!)
              else if (url != null && url.isNotEmpty)
                AtenuadoPorNivel(
                  opacidad: 1 - v,
                  child: ClipRect(
                    child: DesenfoqueHijo(
                      sigma: sigmaFondo,
                      tope: EstiloHelper.topeSigma(sigma),
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
                  ),
                ),
              // Capa 2: velo del tema (legibilidad), que se aclara con la
              // intensidad para que cada porcentaje se note en la carátula.
              ColoredBox(color: colorFondo.withValues(alpha: velo)),
              // Capa 3: color dominante del cover, entrando de a poco.
              if (url != null && url.isNotEmpty)
                AtenuadoPorNivel(
                  opacidad: v,
                  child: _VeloDinamicoReproductor(
                    coverUrl: url,
                    esOscuro: esOscuro,
                    defaultBg: colorFondo,
                  ),
                ),
              // Capa 4: gradiente inferior.
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
      },
    );
  }
}
