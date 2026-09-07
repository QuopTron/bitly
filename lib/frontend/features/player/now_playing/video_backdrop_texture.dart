import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Renders the SAME video texture the cover square is playing, stretched to
/// fill any box (BoxFit.cover). Mounting two full `Video` widgets on one
/// controller would create two native outputs, so this mirrors the raw
/// `Texture` id instead — the frame is drawn in both places from one output.
class VideoBackdropTexture extends StatelessWidget {
  final VideoController controller;

  const VideoBackdropTexture({super.key, required this.controller});

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
