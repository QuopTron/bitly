import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import 'cover_image.dart';

/// A reusable detail page header that extracts dominant colors from the cover
/// image and renders a gradient background. Supports dark/light mode.
///
/// [coverUrl] — network or local path for the cover image.
/// [title] / [subtitle] — text displayed below the cover.
/// [heroTag] — unique tag for Hero animation (e.g. album ID).
/// [actions] — optional row of action buttons (like, download, etc.).
/// [coverSize] — size of the cover image (defaults to ~60% of screen width).
class DetailHeader extends StatefulWidget {
  final String? coverUrl;
  final String title;
  final String subtitle;
  final String? heroTag;
  final Widget? actions;
  final double? coverSize;
  final String? badge;

  const DetailHeader({
    super.key,
    this.coverUrl,
    required this.title,
    required this.subtitle,
    this.heroTag,
    this.actions,
    this.coverSize,
    this.badge,
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
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
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
        maximumColorCount: 8,
      );
      if (mounted) {
        setState(() => _palette = generator);
        _fadeCtrl.forward();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.sizeOf(context).width;
    final coverSize = widget.coverSize ?? (screenW * 0.58).clamp(140.0, 280.0);

    // Extract palette colors with fallbacks
    final dominant = _palette?.dominantColor?.color;
    final vibrant = _palette?.vibrantColor?.color;
    final darkVibrant = _palette?.darkVibrantColor?.color;
    final muted = _palette?.mutedColor?.color;

    // Build gradient colors from palette
    final gradColors = _buildGradientColors(isDark, dominant, vibrant, darkVibrant, muted);
    final textColor = _bestTextColor(gradColors.$1, isDark);

    return AnimatedBuilder(
      animation: _fadeAnim,
      builder: (context, _) {
        final t = _fadeAnim.value;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(isDark ? const Color(0xFF121212) : Colors.white, gradColors.$1, t * 0.85)!,
                Color.lerp(isDark ? const Color(0xFF121212) : Colors.white, gradColors.$2, t * 0.7)!,
                isDark ? const Color(0xFF121212) : Colors.white,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: t * 40, sigmaY: t * 40),
              child: Padding(
                padding: EdgeInsets.fromLTRB(r.spacingM, r.spacingL, r.spacingM, r.spacingM),
                child: Column(
                  children: [
                    SizedBox(height: MediaQuery.paddingOf(context).top + r.spacingS),
                    // Cover image with Hero
                    Hero(
                      tag: widget.heroTag ?? widget.title,
                      child: Container(
                        width: coverSize,
                        height: coverSize,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (dominant ?? Colors.black).withValues(alpha: 0.5 * t),
                              blurRadius: 32,
                              spreadRadius: 4,
                              offset: const Offset(0, 8),
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
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.subtitleSize * 1.15,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
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
                    // Badge (optional — e.g. "8 tracks • Album")
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
                    // Actions row
                    if (widget.actions != null) ...[
                      SizedBox(height: r.spacingS),
                      widget.actions!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds gradient colors from the palette.
  /// Returns (topColor, midColor).
  (Color, Color) _buildGradientColors(
    bool isDark,
    Color? dominant,
    Color? vibrant,
    Color? darkVibrant,
    Color? muted,
  ) {
    if (!isDark) {
      // Light mode: softer, pastel-like
      final top = vibrant ?? dominant ?? AppColors.greenBright;
      final mid = darkVibrant ?? muted ?? top.withValues(alpha: 0.6);
      return (_desaturate(top, 0.3), _desaturate(mid, 0.4));
    }
    // Dark mode: rich, saturated
    final top = vibrant ?? dominant ?? AppColors.greenBright;
    final mid = darkVibrant ?? muted ?? top.withValues(alpha: 0.5);
    return (top.withValues(alpha: 0.7), mid.withValues(alpha: 0.3));
  }

  /// Determines the best text color (white/black) for contrast against [bg].
  Color _bestTextColor(Color bg, bool isDark) {
    final luminance = bg.computeLuminance();
    if (isDark) return luminance > 0.4 ? Colors.black : Colors.white;
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Lightly desaturates a color.
  Color _desaturate(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withSaturation((hsl.saturation * (1 - amount)).clamp(0.0, 1.0)).toColor();
  }
}
