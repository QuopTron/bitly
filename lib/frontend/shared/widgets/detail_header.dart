import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import 'cover_image.dart';

/// Full-screen detail page background that extracts dominant colors from
/// the cover image, renders a blurred version as background with a gradient
/// overlay, and places the sharp cover + title + actions on top.
///
/// Wraps the entire detail page content. The [child] is placed below the
/// header area (cover + title + actions) and scrolls over the gradient.
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

  /// Expose palette colors for child widgets that need them.
  static Color dominantColorOf(BuildContext context) {
    final state = context.findAncestorStateOfType<_DetailHeaderState>();
    return state?._dominantColor ?? AppColors.greenBright;
  }

  @override
  State<DetailHeader> createState() => _DetailHeaderState();
}

class _DetailHeaderState extends State<DetailHeader>
    with SingleTickerProviderStateMixin {
  PaletteGenerator? _palette;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  Color _dominantColor = AppColors.greenBright;

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

  Future<void> _extractColors() async {
    if (widget.coverUrl == null || widget.coverUrl!.isEmpty) return;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(widget.coverUrl!),
        size: const Size(200, 200),
        maximumColorCount: 12,
      );
      if (mounted) {
        setState(() {
          _palette = generator;
          _dominantColor = generator.dominantColor?.color ?? AppColors.greenBright;
        });
        _fadeCtrl.forward();
      }
    } catch (_) {}
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
    final darkVibrant = _palette?.darkVibrantColor?.color;
    final muted = _palette?.mutedColor?.color;
    final lightMuted = _palette?.lightMutedColor?.color;

    // Build gradient colors
    final topColor = _resolveTopColor(isDark, dominant, vibrant, darkVibrant);
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
                  opacity: t * 0.6,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Transform.scale(
                      scale: 1.3,
                      child: imageFromUrl(widget.coverUrl, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),

            // ── Layer 3: Gradient overlay (top-to-bottom fade) ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      topColor.withValues(alpha: 0.85 * t),
                      midColor.withValues(alpha: 0.6 * t),
                      bgColor.withValues(alpha: 0.95),
                      bgColor,
                    ],
                    stops: const [0.0, 0.3, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // ── Layer 4: Vignette for depth ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      bgColor.withValues(alpha: 0.4 * t),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),

            // ── Layer 5: Content ──
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
                            color: (dominant ?? Colors.black).withValues(alpha: 0.6 * t),
                            blurRadius: 40,
                            spreadRadius: 6,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: (vibrant ?? dominant ?? Colors.black).withValues(alpha: 0.3 * t),
                            blurRadius: 80,
                            spreadRadius: 10,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: widget.coverUrl != null && widget.coverUrl!.isNotEmpty
                          ? imageFromUrl(widget.coverUrl, fit: BoxFit.cover)
                          : Container(
                              color: isDark ? Colors.white10 : Colors.black12,
                              child: Icon(
                                Icons.music_note,
                                size: coverSize * 0.3,
                                color: textColor.withValues(alpha: 0.3),
                              ),
                            ),
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
                  SizedBox(height: r.spacingM),
                  // Child content (track list, etc.)
                  if (widget.child != null) Expanded(child: widget.child!),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _resolveTopColor(bool isDark, Color? dominant, Color? vibrant, Color? darkVibrant) {
    final base = vibrant ?? dominant ?? AppColors.greenBright;
    if (!isDark) {
      return HSLColor.fromColor(base)
          .withLightness((HSLColor.fromColor(base).lightness * 0.7).clamp(0.0, 1.0))
          .withSaturation((HSLColor.fromColor(base).saturation * 0.8).clamp(0.0, 1.0))
          .toColor();
    }
    return base.withValues(alpha: 0.75);
  }

  Color _resolveMidColor(bool isDark, Color? muted, Color? lightMuted, Color? dominant) {
    final base = muted ?? lightMuted ?? dominant ?? AppColors.greenBright;
    if (!isDark) {
      return HSLColor.fromColor(base)
          .withLightness(0.85)
          .withSaturation(0.2)
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
