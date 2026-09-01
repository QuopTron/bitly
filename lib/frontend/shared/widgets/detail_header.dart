import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Decode image via Flutter's pipeline and extract dominant color.
Future<Color?> _extractDominantColor(ImageProvider provider) async {
  try {
    final stream = provider.resolve(const ImageConfiguration());
    final completer = Completer<ui.Image?>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    stream.addListener(listener);
    final image = await completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        stream.removeListener(listener);
        return null;
      },
    );
    stream.removeListener(listener);
    if (image == null) return null;
    try {
      final w = image.width;
      final h = image.height;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;
      final data = byteData.buffer.asUint8List();
      int rSum = 0, gSum = 0, bSum = 0, count = 0;
      final stepX = max(1, w ~/ 12);
      final stepY = max(1, h ~/ 12);
      for (int y = h ~/ 4; y < h * 3 ~/ 4; y += stepY) {
        for (int x = w ~/ 4; x < w * 3 ~/ 4; x += stepX) {
          final i = (y * w + x) * 4;
          if (data[i + 3] < 128) continue;
          rSum += data[i];
          gSum += data[i + 1];
          bSum += data[i + 2];
          count++;
        }
      }
      if (count == 0) return null;
      final hsl = HSLColor.fromColor(
          Color.fromARGB(255, rSum ~/ count, gSum ~/ count, bSum ~/ count));
      return hsl
          .withSaturation((hsl.saturation * 0.7).clamp(0.0, 1.0))
          .withLightness(0.18)
          .toColor();
    } finally {
      image.dispose();
    }
  } catch (_) {
    return null;
  }
}

/// Full-screen detail header: blurred cover background + dark gradient overlay.
/// Optimized: shares one ImageProvider for display + color extraction,
/// limits decode size, caches, no raw HTTP downloads.
class DetailHeader extends StatefulWidget {
  final String? coverUrl;
  final String title;
  final String subtitle;
  final String? heroTag;
  final Widget? actions;
  final List<Widget> children;
  final String? badge;
  final double? coverSize;

  const DetailHeader({
    super.key,
    this.coverUrl,
    required this.title,
    required this.subtitle,
    this.heroTag,
    this.actions,
    this.children = const [],
    this.badge,
    this.coverSize,
  });

  @override
  State<DetailHeader> createState() => _DetailHeaderState();
}

class _DetailHeaderState extends State<DetailHeader>
    with SingleTickerProviderStateMixin {
  Color? _dominantColor;
  String? _lastExtractedUrl;
  late final AnimationController _animCtrl;
  late final Animation<double> _anim;

  // Global cache: url -> dominant color (avoids re-extraction across rebuilds)
  static final Map<String, Color> _colorCache = {};

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadCachedColor();
  }

  @override
  void didUpdateWidget(covariant DetailHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) _loadCachedColor();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  bool get _isLocalCover {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return false;
    return url.startsWith('/') || url.startsWith('file://');
  }

  ImageProvider _makeProvider() {
    final url = widget.coverUrl!;
    if (_isLocalCover) {
      final path =
          url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
      return FileImage(File(path));
    }
    return NetworkImage(url);
  }

  void _loadCachedColor() {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return;
    _lastExtractedUrl = url;
    // Check global cache first — instant, no decode needed
    if (_colorCache.containsKey(url)) {
      final cached = _colorCache[url]!;
      if (_dominantColor != cached) {
        _dominantColor = cached;
        // Don't setState — animation already playing from initState
      }
      return;
    }
    // Not cached: extract async
    _extractColor();
  }

  Future<void> _extractColor() async {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return;
    try {
      final provider = _makeProvider();
      final color = await _extractDominantColor(provider);
      if (mounted && color != null && _lastExtractedUrl == url) {
        _colorCache[url] = color;
        // Cap cache at 100 entries to prevent unbounded growth
        while (_colorCache.length > 100) {
          _colorCache.remove(_colorCache.keys.first);
        }
        setState(() => _dominantColor = color);
      }
    } catch (_) {}
  }

  Widget _coverImg(double size) {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return _placeholder(size);
    if (_isLocalCover) {
      final path =
          url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: size.toInt() * 2, // 2x for Retina but not full res
        errorBuilder: (c, e, s) => _placeholder(size),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: size.toInt() * 2,
      errorBuilder: (c, e, s) => _placeholder(size),
      gaplessPlayback: true,
    );
  }

  /// Blurred background: uses a tiny 60px-wide decode to minimize GPU cost.
  Widget _blurredBg() {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    if (_isLocalCover) {
      final path =
          url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: 60, // tiny — we blur it anyway
        errorBuilder: (c, e, s) => const SizedBox.shrink(),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 60, // tiny — we blur it anyway
      errorBuilder: (c, e, s) => const SizedBox.shrink(),
      gaplessPlayback: true,
    );
  }

  Widget _placeholder(double size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? Colors.white10 : Colors.black12,
      child: Icon(Icons.music_note,
          size: size * 0.3,
          color:
              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.sizeOf(context).width;
    final coverSz = widget.coverSize ?? (screenW * 0.52).clamp(140.0, 240.0);
    final statusBar = MediaQuery.paddingOf(context).top;
    final bgColor =
        isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
    final accent = _dominantColor ??
        (isDark ? const Color(0xFF1A1A2E) : const Color(0xFFE8E8E8));

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        return Stack(
          children: [
            // ── Layer 1: Base ──
            Positioned.fill(child: Container(color: bgColor)),

            // ── Layer 2: Blurred cover (isolated repaint) ──
            if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty)
              Positioned.fill(
                child: RepaintBoundary(
                  child: Opacity(
                    opacity: t * 0.65,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                      child: Transform.scale(
                        scale: 1.5,
                        child: _blurredBg(),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Layer 3: Gradient (RepaintBoundary) ──
            Positioned.fill(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent.withValues(alpha: 0.85 * t),
                        accent.withValues(alpha: 0.6 * t),
                      bgColor.withValues(alpha: 0.95),
                      bgColor,
                    ],
                    stops: const [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
              ),
              ),
            ),

            // ── Layer 4: Content ──
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(height: statusBar),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.spacingS),
                    child: Column(
                      children: [
                        // Cover with Hero + glow
                        Hero(
                          tag: widget.heroTag ?? widget.title,
                          child: Container(
                            width: coverSz,
                            height: coverSz,
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.7 * t),
                                  blurRadius: 50,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: _coverImg(coverSz),
                          ),
                        ),
                        SizedBox(height: r.spacingM),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: r.subtitleSize * 1.3,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: r.subtitleSize * 0.9,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        if (widget.badge != null) ...[
                          SizedBox(height: 6),
                          Text(
                            widget.badge!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: r.footerSize + 1,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                        if (widget.actions != null) ...[
                          SizedBox(height: r.spacingS),
                          widget.actions!,
                        ],
                        SizedBox(height: r.spacingS),
                      ],
                    ),
                  ),
                  ...widget.children,
                  SizedBox(
                      height: MediaQuery.paddingOf(context).bottom + 90),
                ],
              ),
            ),

            // ── Layer 5: Back button ──
            Positioned(
              top: statusBar + 4,
              left: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
