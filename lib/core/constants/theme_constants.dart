import 'package:flutter/material.dart';

class ThemeConstants {
  ThemeConstants._();

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  static const EdgeInsets screenPadding = EdgeInsets.all(spacingMd);
  static const EdgeInsets cardPadding = EdgeInsets.all(spacingMd);
  static const EdgeInsets listPadding = EdgeInsets.symmetric(
    horizontal: spacingMd,
    vertical: spacingSm,
  );
}
