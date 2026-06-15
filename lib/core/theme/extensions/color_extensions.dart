import 'package:flutter/material.dart';

extension ColorExtensions on Color {
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final dark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return dark.toColor();
  }

  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final light = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return light.toColor();
  }

  Color withOpacityNormally(double opacity) {
    return withValues(alpha: opacity);
  }

  bool get isLight {
    final luminance = computeLuminance();
    return luminance > 0.5;
  }

  Color get readableTextColor {
    return isLight ? Colors.black : Colors.white;
  }
}
