import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/responsive.dart';

/// Fast color extraction from image bytes — no PaletteGenerator overhead.
/// Samples a grid of pixels from the decoded image and clusters by hue.
Future<List<Color>> _extractColorsFast(Uint8List bytes, {int count = 5}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final w = image.width;
    final h = image.height;
    // Read a small region (center 50%)
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];
    final data = byteData.buffer.asUint8List();

    // Sample a grid of pixels
    final colors = <Color>[];
    final stepX = max(1, w ~/ 16);
    final stepY = max(1, h ~/ 16);
    for (int y = h ~/ 4; y < h * 3 ~/ 4; y += stepY) {
      for (int x = w ~/ 4; x < w * 3 ~/ 4; x += stepX) {
        final i = (y * w + x) * 4;
        final r = data[i];
        final g = data[i + 1];
        final b = data[i + 2];
        final a = data[i + 3];
        if (a < 128) continue; // skip transparent
        final c = Color.fromARGB(255, r, g, b);
        // Skip near-black and near-white
        if (c.computeLuminance() < 0.05 || c.computeLuminance() > 0.92) continue;
        colors.add(c);
      }
    }

    if (colors.isEmpty) return [];

    // Sort by saturation descending, pick top N most vibrant
    colors.sort((a, b) {
      final hslA = HSLColor.fromColor(a);
      final hslB = HSLColor.fromColor(b);
      return (hslB.saturation * 0.7 + hslB.lightness * 0.3)
          .compareTo(hslA.saturation * 0.7 + hslA.lightness * 0.3);
    });

    // Pick diverse colors (different hue buckets)
    final picked = <Color>[];
    final usedHues = <int>{};
    for (final c in colors) {
      if (picked.length >= count) break;
      final hue = HSLColor.fromColor(c).hue.toInt() ~/ 30; // 12 buckets
      if (usedHues.contains(hue)) continue;
      usedHues.add(hue);
      picked.add(c);
    }
    // Fill remaining from top if not enough diverse colors
    for (final c in colors) {
      if (picked.length >= count) break;
      if (!picked.contains(c)) picked.add(c);
    }

    return picked;
  } finally {
    image.dispose();
  }
}

/// Full-screen detail page background that extracts dominant colors from
/// the cover image instantly, renders a blurred version as background with
/// a vibrant gradient overlay, and places everything in a single scrollable
/// ListView with a back button.
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
  List<Color> _colors = [];
  late final AnimationController _animCtrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    // Start animation IMMEDIATELY — don't wait for color extraction
    _animCtrl.forward();
    _extractColors();
  }

  @override
  void didUpdateWidget(covariant DetailHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) _extractColors();
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

  Future<void> _extractColors() async {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return;
    try {
      Uint8List? bytes;
      if (_isLocalCover) {
        final path =
            url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
        final file = File(path);
        if (!await file.exists()) return;
        bytes = await file.readAsBytes();
      } else {
        final uri = Uri.parse(url);
        final request = await HttpClient().getUrl(uri);
        final response = await request.close();
        bytes = await consolidateHttpClientResponseBytes(response);
        await response.drain();
      }
      if (bytes.isEmpty) return;
      final colors = await _extractColorsFast(bytes);
      if (mounted && colors.isNotEmpty) {
        setState(() => _colors = colors);
      }
    } catch (_) {}
  }

  Widget _coverImg(double size) {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return _placeholder(size);
    if (_isLocalCover) {
      final path =
          url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
      return Image.file(File(path), fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _placeholder(size));
    }
    return Image.network(url, fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _placeholder(size), gaplessPlayback: true);
  }

  Widget _blurredImg() {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    if (_isLocalCover) {
      final path =
          url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
      return Image.file(File(path), fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const SizedBox.shrink());
    }
    return Image.network(url, fit: BoxFit.cover,
        errorBuilder: (c, e, s) => const SizedBox.shrink(), gaplessPlayback: true);
  }

  Widget _placeholder(double size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? Colors.white10 : Colors.black12,
      child: Icon(Icons.music_note, size: size * 0.3,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.sizeOf(context).width;
    final coverSz = widget.coverSize ?? (screenW * 0.52).clamp(140.0, 240.0);
    final statusBar = MediaQuery.paddingOf(context).top;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);

    // Extract colors from our fast extraction
    final primary = _colors.isNotEmpty ? _colors[0] : null;
    final secondary = _colors.length > 1 ? _colors[1] : null;
    final tertiary = _colors.length > 2 ? _colors[2] : null;

    final topColor = _boostColor(primary ?? AppColors.greenBright, isDark);
    final midColor = _boostColor(
        secondary ?? primary ?? AppColors.greenBright, isDark, muted: true);
    final bottomColor = _boostColor(
        tertiary ?? secondary ?? primary ?? AppColors.greenBright,
        isDark,
        muted: true);
    final textColor = _bestTextColor(topColor, isDark);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        return Stack(
          children: [
            // ── Layer 1: Base ──
            Positioned.fill(child: Container(color: bgColor)),

            // ── Layer 2: Blurred cover (starts immediately) ──
            if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: t * 0.7,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                    child: Transform.scale(
                      scale: 1.5,
                      child: _blurredImg(),
                    ),
                  ),
                ),
              ),

            // ── Layer 3: Gradient ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      topColor.withValues(alpha: 0.9 * t),
                      midColor.withValues(alpha: 0.6 * t),
                      bottomColor.withValues(alpha: 0.3 * t),
                      bgColor.withValues(alpha: 0.9),
                      bgColor,
                    ],
                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // ── Layer 4: Content ──
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Top spacer + back button area
                  SizedBox(height: statusBar),

                  // Content with horizontal padding
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.spacingS),
                    child: Column(
                      children: [
                        // Cover with Hero + glow shadow
                        Hero(
                          tag: widget.heroTag ?? widget.title,
                          child: Container(
                            width: coverSz,
                            height: coverSz,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: (primary ?? Colors.black)
                                      .withValues(alpha: 0.7 * t),
                                  blurRadius: 50,
                                  spreadRadius: 6,
                                  offset: const Offset(0, 14),
                                ),
                                BoxShadow(
                                  color: (secondary ?? primary ?? Colors.black)
                                      .withValues(alpha: 0.35 * t),
                                  blurRadius: 90,
                                  spreadRadius: 12,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: _coverImg(coverSz),
                          ),
                        ),

                        SizedBox(height: r.spacingM),

                        // Title
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: r.subtitleSize * 1.3,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),

                        SizedBox(height: 4),

                        // Subtitle
                        Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: r.footerSize,
                            fontWeight: FontWeight.w500,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),

                        // Badge
                        if (widget.badge != null) ...[
                          SizedBox(height: 4),
                          Text(
                            widget.badge!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: r.footerSize - 1,
                              color: textColor.withValues(alpha: 0.35),
                            ),
                          ),
                        ],

                        // Actions
                        if (widget.actions != null) ...[
                          SizedBox(height: r.spacingS),
                          widget.actions!,
                        ],

                        SizedBox(height: r.spacingS),
                      ],
                    ),
                  ),

                  // Child content items (full width)
                  ...widget.children,

                  // Bottom safe area
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 90),
                ],
              ),
            ),

            // ── Layer 5: Back button (fixed position) ──
            Positioned(
              top: statusBar + 4,
              left: 8,
              child: SafeArea(
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
            ),
          ],
        );
      },
    );
  }

  /// Boost saturation/lightness to make gradient vibrant.
  Color _boostColor(Color c, bool isDark, {bool muted = false}) {
    var hsl = HSLColor.fromColor(c);
    if (muted) {
      // Muted variant: lower saturation, slightly darker
      hsl = hsl.withSaturation((hsl.saturation * 0.5).clamp(0.0, 1.0))
          .withLightness(isDark ? 0.3 : 0.7);
    } else {
      // Primary: boost saturation, ensure visible
      hsl = hsl.withSaturation((hsl.saturation * 1.2).clamp(0.0, 1.0))
          .withLightness(isDark ? 0.45 : 0.55);
    }
    return hsl.toColor();
  }

  Color _bestTextColor(Color bg, bool isDark) {
    final luminance = bg.computeLuminance();
    if (isDark) return luminance > 0.35 ? Colors.black : Colors.white;
    return luminance > 0.55 ? Colors.black87 : Colors.white;
  }
}
