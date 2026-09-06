import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'cover_image.dart';

/// Blurred album-art backdrop that fills its parent.
///
/// When [coverUrl] is provided the cover is blurred (sigma 50) and scaled to
/// fill, then tinted with [bgColor] at ~60 % (dark) / ~40 % (light) so the
/// page stays readable.  Falls back to a solid [bgColor] when there is no
/// cover.
class AmbientBackdrop extends StatelessWidget {
  final String? coverUrl;
  final bool isDark;
  final Color bgColor;

  const AmbientBackdrop({
    super.key,
    required this.coverUrl,
    required this.isDark,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty) ...[
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Transform.scale(
                  scale: 1.25,
                  child: imageFromUrl(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          ] else
            ColoredBox(color: bgColor),
          // Theme veil — keeps the page genuinely dark / light.
          ColoredBox(color: bgColor.withValues(alpha: isDark ? 0.66 : 0.42)),
          // Extra bottom dim so controls stay readable.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  bgColor.withValues(alpha: isDark ? 0.35 : 0.25),
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
