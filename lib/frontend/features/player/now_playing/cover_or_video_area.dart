import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../shared/models/feed_models.dart';
import '../../../shared/widgets/cover_image.dart';

class CoverOrVideoArea extends StatelessWidget {
  final FeedItem track;
  final String? resolvedCover;
  final bool isDark;
  final bool showVideo;
  final bool hasVideo;
  final VideoController? videoController;
  final VoidCallback? onToggleVideo;
  final VoidCallback? onStopVideo;

  const CoverOrVideoArea({
    super.key,
    required this.track,
    required this.resolvedCover,
    required this.isDark,
    this.showVideo = false,
    this.hasVideo = false,
    this.videoController,
    this.onToggleVideo,
    this.onStopVideo,
  });

  @override
  Widget build(BuildContext context) {
    final side = (MediaQuery.sizeOf(context).width * 0.76).clamp(0.0, 420.0);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: hasVideo ? onToggleVideo : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.30),
                blurRadius: 44,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              width: side,
              height: side,
              child: showVideo
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Video(controller: videoController!, fill: Colors.transparent, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: onStopVideo,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.image, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        CoverImage(
                          coverUrl: resolvedCover,
                          localPath: null,
                          width: side,
                          height: side,
                        ),
                        if (hasVideo)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: onToggleVideo,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.videocam, color: Colors.white, size: 18),
                              ),
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
}

String? resolveLocalVideoUrl(FeedItem track, String? downloadPath) {
  if (downloadPath == null) return null;
  final videoExts = ['mp4', 'webm', 'mkv', 'avi'];
  for (final ext in videoExts) {
    final path = '$downloadPath\\${track.id}.$ext';
    if (File(path).existsSync()) return 'file://${path.replaceAll('\\', '/')}';
  }
  if (track.name.isNotEmpty && track.artists != null && track.artists!.isNotEmpty) {
    const invalid = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    String sanitize(String s) {
      var r = s;
      for (final ch in invalid) r = r.replaceAll(ch, '_');
      r = r.replaceAll(RegExp(r'[. ]+$'), '');
      return r.isEmpty ? 'unknown' : r;
    }
    final stem = '${sanitize(track.artists!)} - ${sanitize(track.name)}';
    for (final ext in videoExts) {
      final path = '$downloadPath\\$stem.$ext';
      if (File(path).existsSync()) return 'file://${path.replaceAll('\\', '/')}';
    }
  }
  return null;
}
