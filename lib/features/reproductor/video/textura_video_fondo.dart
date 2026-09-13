// ─────────────────────────────────────────────────────────────
// textura_video_fondo.dart — Renderiza la MISMA textura de video
// que reproduce la portada cuadrada, estirada para llenar
// cualquier caja (BoxFit.cover). Montar dos widgets `Video` sobre
// un mismo controller crearía dos salidas nativas, así que esto
// refleja el `Texture` crudo: el frame se dibuja en ambos lugares
// desde una sola salida.
// Se conecta con: media_kit_video + area_portada_video.
// Parte del flujo: reproductor (fondo de video visualizador).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Textura del video actual estirada para llenar el fondo.
class TexturaVideoFondo extends StatelessWidget {
  final VideoController controller;

  const TexturaVideoFondo({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: controller.id,
      builder: (context, id, _) {
        if (id == null) return const ColoredBox(color: Colors.black);
        return ValueListenableBuilder<Rect?>(
          valueListenable: controller.rect,
          builder: (context, rect, _) {
            final r = rect ?? const Rect.fromLTWH(0, 0, 16, 16);
            if (r.width <= 1 || r.height <= 1) {
              return const ColoredBox(color: Colors.black);
            }
            return ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: r.width,
                  height: r.height,
                  child: Texture(textureId: id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}