import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Returns true if [url] points to a local file path.
bool isLocalUrl(String url) =>
    url.startsWith('/') || url.startsWith(r'\\') || (url.length > 3 && url[1] == ':');

/// Builds an [Image] widget from a remote URL or local file path.
/// Returns [fallback] if the url is empty or on error.
///
/// Decode/memory sizing, low filter quality, a short fade and
/// useOldImageOnUrlChange follow SpotiFLAC's cover handling so covers load
/// fast, smoothly and with a bounded memory footprint.
Widget imageFromUrl(String? url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? fallback,
}) {
  if (url == null || url.isEmpty) {
    return fallback ?? const SizedBox.shrink();
  }
  if (isLocalUrl(url)) {
    return Image.file(
      File(url),
      width: width, height: height, fit: fit,
      cacheWidth: _cacheExtentFor(width),
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => fallback ?? const SizedBox.shrink(),
    );
  }
  return CachedNetworkImage(
    imageUrl: url,
    width: width, height: height, fit: fit,
    memCacheWidth: _cacheExtentFor(width),
    filterQuality: FilterQuality.low,
    useOldImageOnUrlChange: true,
    fadeInDuration: const Duration(milliseconds: 150),
    fadeOutDuration: const Duration(milliseconds: 100),
    placeholder: (_, _) => const SizedBox.shrink(),
    errorWidget: (_, _, _) => fallback ?? const SizedBox.shrink(),
  );
}

/// Computes a bounded decode size for an image of logical [size] pixels
/// (retina ×2, clamped between 64 and 512 px) to save memory on small covers.
int? _cacheExtentFor(double? size) {
  if (size == null || !size.isFinite || size <= 0) return null;
  return (size * 2).round().clamp(64, 512);
}

// ── Animated shimmer placeholder ──────────────────────────────────

/// A simple shimmer effect using a sweeping gradient. No external deps.
class _ShimmerPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? bgColor;

  const _ShimmerPlaceholder({
    this.width,
    this.height,
    this.borderRadius = 0,
    this.bgColor,
  });

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.bgColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFE8E8E8));
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * t, 0),
              end: Alignment(-0.5 + 2.0 * t, 0),
              colors: [
                base,
                base.withValues(alpha: 0.5),
                base,
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── CoverImage widget ─────────────────────────────────────────────

class CoverImage extends StatelessWidget {
  final String? coverUrl;
  final String? localPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? fallback;
  final Color? fallbackBg;

  /// When true, shows an animated shimmer while the image loads.
  final bool showShimmer;

  /// When non-null, renders a soft colored glow behind the image
  /// (e.g. the dominant color of the cover). Alpha controls intensity.
  final Color? glowColor;

  /// Spread radius of the glow when [glowColor] is set. Default 6.
  final double glowSpread;

  const CoverImage({
    super.key,
    this.coverUrl,
    this.localPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.fallback,
    this.fallbackBg,
    this.showShimmer = false,
    this.glowColor,
    this.glowSpread = 6,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    Widget image = _buildImage(context);

    // Optional shimmer behind the image
    if (showShimmer) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          _ShimmerPlaceholder(
            width: width,
            height: height,
            borderRadius: borderRadius,
            bgColor: fallbackBg,
          ),
          image,
        ],
      );
    }

    // Optional glow behind the image
    if (glowColor != null) {
      image = Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.35),
              blurRadius: glowSpread * 2,
              spreadRadius: glowSpread,
            ),
          ],
        ),
        child: ClipRRect(borderRadius: radius, child: image),
      );
    } else if (borderRadius > 0) {
      image = ClipRRect(borderRadius: radius, child: image);
    }

    return image;
  }

  Widget _buildImage(BuildContext context) {
    if (localPath != null && localPath!.isNotEmpty) {
      if (localPath!.startsWith('http://') || localPath!.startsWith('https://')) {
        return imageFromUrl(localPath, width: width, height: height, fit: fit,
            fallback: fallback ?? _defaultFallback(context));
      }
      if (File(localPath!).existsSync()) {
        return imageFromUrl(localPath, width: width, height: height, fit: fit,
            fallback: fallback ?? _defaultFallback(context));
      }
    }

    return imageFromUrl(coverUrl, width: width, height: height, fit: fit,
        fallback: fallback ?? _defaultFallback(context));
  }

  Widget _defaultFallback(BuildContext context) {
    if (fallbackBg != null) {
      return Container(
        width: width,
        height: height,
        color: fallbackBg,
      );
    }
    return const SizedBox.shrink();
  }
}
