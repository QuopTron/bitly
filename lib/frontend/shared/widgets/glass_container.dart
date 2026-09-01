import 'dart:ui';
import 'package:flutter/material.dart';

/// Modern glassmorphism container with optional real blur and gradient.
///
/// All new parameters default to the previous behavior (no blur, no gradient)
/// so existing callers continue to work identically.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? bgColor;

  // ── New glass parameters (opt-in) ──────────────────────────

  /// When non-null, applies a [BackdropFilter] with this blur sigma.
  /// Typical values: 12–24. Set to null (default) to disable blur.
  final double? blurSigma;

  /// Optional gradient overlay rendered on top of [bgColor].
  /// Useful for subtle diagonal tints (e.g. transparent → green 2%).
  final Gradient? gradient;

  /// When true, renders a soft outer glow using [borderColor] with
  /// a spread radius, giving a neon-glass feel.
  final bool glowBorder;

  /// Spread radius of the glow when [glowBorder] is true. Default 4.
  final double glowSpread;

  /// Blur radius of the glow when [glowBorder] is true. Default 12.
  final double glowBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.borderColor,
    this.borderWidth = 0.8,
    this.margin,
    this.padding,
    this.bgColor,
    this.blurSigma,
    this.gradient,
    this.glowBorder = false,
    this.glowSpread = 4,
    this.glowBlur = 12,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius;
    final border = borderColor ?? Colors.transparent;

    // ── Glow shadow ──
    final shadows = glowBorder
        ? [
            BoxShadow(
              color: border.withValues(alpha: 0.18),
              blurRadius: glowBlur,
              spreadRadius: glowSpread,
            ),
          ]
        : null;

    // Skip BackdropFilter when no blur is requested — saves GPU compositing
    // on the 40+ places GlassContainer is used across the app.
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: bgColor ?? Colors.transparent,
        gradient: gradient,
        border: Border.all(color: border, width: borderWidth),
        boxShadow: shadows,
      ),
      child: child,
    );

    Widget inner = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blurSigma != null
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma!, sigmaY: blurSigma!),
              child: content,
            )
          : content,
    );

    if (margin != null) {
      inner = Padding(padding: margin!, child: inner);
    }

    return inner;
  }
}
