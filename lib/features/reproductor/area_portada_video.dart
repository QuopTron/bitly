// ─────────────────────────────────────────────────────────────
// area_portada_video.dart — Área cuadrada del NowPlaying: la
// portada con botón de videocam (alterna al video visualizador)
// o el video en vivo con botón para volver a la portada. El Video
// SIEMPRE está montado (escondido bajo la portada) para que la
// superficie exista antes de abrir medios (mpv necesita la textura).
// Se conecta con: imagen_portada + media_kit_video.
// Parte del flujo: reproductor (NowPlaying, área central).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/modelos/item_feed.dart';
import '../../shared/widgets/imagen_portada.dart';

/// Portada o video visualizador del track con botones de alternancia.
class AreaPortadaVideo extends StatelessWidget {
  final ItemFeed track;
  final String? caratulaResuelta;
  final bool esOscuro;
  final bool mostrarVideo;
  final bool tieneVideo;
  final bool videoCargando;
  final VideoController? videoController;
  final VoidCallback? onAlternarVideo;
  final VoidCallback? onDetenerVideo;

  const AreaPortadaVideo({
    super.key,
    required this.track,
    required this.caratulaResuelta,
    required this.esOscuro,
    this.mostrarVideo = false,
    this.tieneVideo = false,
    this.videoCargando = false,
    this.videoController,
    this.onAlternarVideo,
    this.onDetenerVideo,
  });

  @override
  Widget build(BuildContext context) {
    final lado = (MediaQuery.sizeOf(context).width * 0.76).clamp(0.0, 420.0);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: tieneVideo ? onAlternarVideo : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: esOscuro ? 0.55 : 0.30),
                blurRadius: 44,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              width: lado,
              height: lado,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Capa de video: transparente al esconderla, arriba al activar.
                  Video(
                    controller: videoController!,
                    fill: Colors.transparent,
                    fit: BoxFit.cover,
                    controls: NoVideoControls,
                  ),
                  // Capa de portada: visible salvo cuando el video está activo;
                  // bloquea los toques para que caigan en el botón de alternar.
                  if (!mostrarVideo)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: tieneVideo ? onAlternarVideo : null,
                        child: ImagenPortada(
                          coverUrl: caratulaResuelta,
                          ancho: lado,
                          alto: lado,
                        ),
                      ),
                    ),
                  if (mostrarVideo)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: onDetenerVideo,
                        child: _chipVideo(
                          const Icon(Icons.image, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  if (!mostrarVideo && tieneVideo)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: videoCargando
                          ? _chipVideo(const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ))
                          : GestureDetector(
                              onTap: onAlternarVideo,
                              child: _chipVideo(const Icon(Icons.videocam,
                                  color: Colors.white, size: 22)),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Chip flotante del área (videocam / imagen / spinner).
  Widget _chipVideo(Widget child) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }
}