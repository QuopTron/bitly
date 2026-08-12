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

class CoverImage extends StatelessWidget {
  final String? coverUrl;
  final String? localPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? fallback;
  final Color? fallbackBg;

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
  });

  @override
  Widget build(BuildContext context) {
    if (localPath != null && localPath!.isNotEmpty) {
      if (localPath!.startsWith('http://') || localPath!.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: imageFromUrl(localPath, width: width, height: height, fit: fit, fallback: fallback),
        );
      }
      if (File(localPath!).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: imageFromUrl(localPath, width: width, height: height, fit: fit, fallback: fallback),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageFromUrl(coverUrl, width: width, height: height, fit: fit, fallback: fallback),
    );
  }
}

