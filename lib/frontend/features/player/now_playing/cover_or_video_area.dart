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
  final bool videoLoading;
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
    this.videoLoading = false,
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
              // The Video widget is ALWAYS mounted (hidden under the cover
              // until showVideo) so the video surface + texture exist before
              // media is opened. Opening a video before its Video widget has
              // mounted leaves mpv without a surface to decode onto
              // (h264_mediacodec: Both surface and native_window are NULL)
              // and playback stalls at loading forever.
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video layer: transparent when hidden, on top when active.
                  Video(
                    controller: videoController!,
                    fill: Colors.transparent,
                    fit: BoxFit.cover,
                    controls: NoVideoControls,
                  ),
                  // Cover layer: shown whenever video is NOT active; it also
                  // blocks touches so taps land on the video toggle button
                  // instead of the video surface underneath.
                  if (!showVideo)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: hasVideo ? onToggleVideo : null,
                        child: CoverImage(
                          coverUrl: resolvedCover,
                          localPath: null,
                          width: side,
                          height: side,
                        ),
                      ),
                    ),
                  if (showVideo)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: onStopVideo,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.image, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  if (!showVideo && hasVideo)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: videoLoading
                          ? Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: onToggleVideo,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                ),
                                child: const Icon(Icons.videocam, color: Colors.white, size: 22),
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
