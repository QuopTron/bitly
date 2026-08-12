import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? bgColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.borderColor,
    this.borderWidth = 0.8,
    this.margin,
    this.padding,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? Colors.transparent, width: borderWidth),
      ),
      child: child,
    );

    if (margin != null) {
      inner = Padding(padding: margin!, child: inner);
    }

    return inner;
  }
}

