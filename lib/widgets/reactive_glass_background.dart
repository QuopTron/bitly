import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/providers/playback_queue_provider.dart';
import 'package:bitly/services/library/covers/cover_cache_manager.dart';
import 'package:bitly/theme/app_theme.dart';

/// Full-screen glass background that adapts to the currently playing track's cover.
/// For specific screens (artist, album, playlist), pass [coverUrl] explicitly.
class ReactiveGlassBackground extends ConsumerWidget {
  final Widget child;
  final String? coverUrl;

  const ReactiveGlassBackground({super.key, required this.child, this.coverUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? effectiveCover;
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      effectiveCover = coverUrl;
    } else {
      effectiveCover = ref.watch(
        playbackQueueProvider.select(
          (q) => q.currentIndex >= 0 && q.currentIndex < q.items.length
              ? q.items[q.currentIndex].track.coverUrl
              : null,
        ),
      );
    }

    return Stack(
      children: [
        _GlassBackground(
          coverUrl: effectiveCover,
          colorScheme: colorScheme,
          isDark: isDark,
        ),
        child,
      ],
    );
  }
}

class _GlassBackground extends StatelessWidget {
  final String? coverUrl;
  final ColorScheme colorScheme;
  final bool isDark;

  const _GlassBackground({
    required this.coverUrl,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Widget? coverWidget;
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      if (coverUrl!.startsWith('http://') || coverUrl!.startsWith('https://')) {
        coverWidget = CachedNetworkImage(
          imageUrl: coverUrl!,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          cacheManager: CoverCacheManager.instance,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        );
      } else {
        coverWidget = Image.file(
          File(coverUrl!),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }

    return RepaintBoundary(
      child: Stack(
        children: [
          // Fallback gradient when no cover
          if (coverWidget == null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: isDark ? AppTheme.gradientDark : AppTheme.gradientLight,
                ),
              ),
            )
          else
            Positioned.fill(child: coverWidget),
          // Blur layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Surface overlay
          Positioned.fill(
            child: Container(
              color: colorScheme.surface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
