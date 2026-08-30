import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../theme/app_colors.dart';
import '../utils/responsive.dart';

/// Full-screen detail page background that extracts dominant colors from
/// the cover image, renders a blurred version as background with a gradient
/// overlay, and places the sharp cover + title + actions on top.
class DetailHeader extends StatefulWidget {
  final String? coverUrl;
  final String title;
  final String subtitle;
  final String? heroTag;
  final Widget? actions;
  final Widget? child;
  final String? badge;
  final double? coverSize;

  const DetailHeader({
    super.key,
    this.coverUrl,
    required this.title,
    required this.subtitle,
    this.heroTag,
    this.actions,
    this.child,
    this.badge,
    this.coverSize,
  });

  @override
  State<DetailHeader> createState() => _DetailHeaderState();
}

class _DetailHeaderState extends State<DetailHeader>
    with SingleTickerProviderStateMixin {
  PaletteGenerator? _palette;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _extractColors();
  }

  @override
  void didUpdateWidget(covariant DetailHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) _extractColors();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  bool get _isLocalCover {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return false;
    return url.startsWith('/') || url.startsWith('file://');
  }

  Future<void> _extractColors() async {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty || _isLocalCover) {
      // For local files, try to extract from file
      if (_isLocalCover) {
        try {
          final path = url!.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
          final file = File(path);
          if (await file.exists()) {
            final generator = await PaletteGenerator.fromImageProvider(
              FileImage(file),
              size: const Size(200, 200),
              maximumColorCount: 12,
            );
            if (mounted) {
              setState(() => _palette = generator);
              _fadeCtrl.forward();
            }
            return;
          }
        } catch (_) {}
      }
      // No cover or can't extract — just fade in with defaults
      if (mounted) _fadeCtrl.forward();
      return;
    }
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        size: const Size(200, 200),
        maximumColorCount: 12,
      );
      if (mounted) {
        setState(() => _palette = generator);
        _fadeCtrl.forward();
      }
    } catch (_) {
      if (mounted) _fadeCtrl.forward();
    }
  }

  /// Builds the cover image widget — handles both local files and network URLs.
  Widget _buildCoverImage(double size) {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) {
      return _placeholderCover(size);
    }
    if (_isLocalCover) {
      final path = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderCover(size),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholderCover(size),
    );
  }

  /// Builds the blurred background cover.
  Widget _buildBlurredBackground() {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    if (_isLocalCover) {
      final path = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  Widget _placeholderCover(double size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? Colors.white10 : Colors.black12,
      child: Icon(
        Icons.music_note,
        size: size * 0.3,
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.sizeOf(context).width;
    final coverSize = widget.coverSize ?? (screenW * 0.55).clamp(140.0, 260.0);
    final statusBar = MediaQuery.paddingOf(context).top;

    // Extract palette colors
    final dominant = _palette?.dominantColor?.color;
    final vibrant = _palette?.vibrantColor?.color;
    final muted = _palette?.mutedColor?.color;
    final lightMuted = _palette?.lightMutedColor?.color;

    // Build gradient colors
    final topColor = _resolveTopColor(isDark, dominant, vibrant);
    final midColor = _resolveMidColor(isDark, muted, lightMuted, dominant);
    final textColor = _bestTextColor(topColor, isDark);

    return AnimatedBuilder(
      animation: _fadeAnim,
      builder: (context, _) {
        final t = _fadeAnim.value;
        final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);

        return Stack(
          children: [
            // ── Layer 1: Base background ──
            Positioned.fill(child: Container(color: bgColor)),

            // ── Layer 2: Blurred cover as background ──
            if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: t * 0.55,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Transform.scale(
                      scale: 1.4,
                      child: _buildBlurredBackground(),
                    ),
                  ),
                ),
              ),

            // ── Layer 3: Gradient overlay ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      topColor.withValues(alpha: 0.8 * t),
                      midColor.withValues(alpha: 0.5 * t),
                      bgColor.withValues(alpha: 0.92),
                      bgColor,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // ── Layer 4: Vignette ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.3,
                    colors: [
                      Colors.transparent,
                      bgColor.withValues(alpha: 0.3 * t),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // ── Layer 5: Content (scrollable) ──
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: statusBar + r.spacingM),
                  // Cover image with Hero + glow
                  Hero(
                    tag: widget.heroTag ?? widget.title,
                    child: Container(
                      width: coverSize,
                      height: coverSize,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: (dominant ?? Colors.black).withValues(alpha: 0.55 * t),
                            blurRadius: 40,
                            spreadRadius: 6,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: (vibrant ?? dominant ?? Colors.black).withValues(alpha: 0.25 * t),
                            blurRadius: 80,
                            spreadRadius: 10,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: _buildCoverImage(coverSize),
                    ),
                  ),
                  SizedBox(height: r.spacingM),
                  // Title
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.spacingL),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.subtitleSize * 1.2,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.4,
                        height: 1.1,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  // Subtitle
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.spacingL),
                    child: Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.footerSize,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.65),
                      ),
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
                        color: textColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                  // Actions
                  if (widget.actions != null) ...[
                    SizedBox(height: r.spacingS),
                    widget.actions!,
                  ],
                  SizedBox(height: r.spacingS),
                  // Child content — Expanded so it takes remaining space
                  if (widget.child != null)
                    Expanded(child: widget.child!),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _resolveTopColor(bool isDark, Color? dominant, Color? vibrant) {
    final base = vibrant ?? dominant ?? AppColors.greenBright;
    if (!isDark) {
      return HSLColor.fromColor(base)
          .withLightness(0.55)
          .withSaturation(0.7)
          .toColor();
    }
    return base.withValues(alpha: 0.75);
  }

  Color _resolveMidColor(bool isDark, Color? muted, Color? lightMuted, Color? dominant) {
    final base = muted ?? lightMuted ?? dominant ?? AppColors.greenBright;
    if (!isDark) {
      return HSLColor.fromColor(base)
          .withLightness(0.85)
          .withSaturation(0.15)
          .toColor();
    }
    return base.withValues(alpha: 0.3);
  }

  Color _bestTextColor(Color bg, bool isDark) {
    final luminance = bg.computeLuminance();
    if (isDark) return luminance > 0.35 ? Colors.black : Colors.white;
    return luminance > 0.55 ? Colors.black87 : Colors.white;
  }
}
