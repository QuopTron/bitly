import 'package:flutter/material.dart';

class Responsive {
  final BuildContext context;
  late final double width;
  late final double height;
  late final double scale;

  static const double _base = 400;

  Responsive(this.context) {
    final size = MediaQuery.of(context).size;
    width = size.width;
    height = size.height;
    scale = (size.shortestSide / _base).clamp(0.6, 1.1);
  }

  double get logoSize => (114 * scale).clamp(66, 200);
  double get circlePadding => (23 * scale).clamp(13, 40);
  double get titleSize => (21 * scale).clamp(15, 34);
  double get subtitleSize => (13 * scale).clamp(11, 19);
  double get footerSize => (9 * scale).clamp(8, 14);
  double get retryButtonHeight => (40 * scale).clamp(32, 54);
  double get continueButtonHeight => (44 * scale).clamp(36, 58);
  double get languageCardVPadding => (15 * scale).clamp(11, 26);
  double get languageCardHPadding => (19 * scale).clamp(13, 34);
  double get languageCardMargin => (27 * scale).clamp(17, 52);
  double get languageCardIconSize => (34 * scale).clamp(26, 46);
  double get languageCheckSize => (13 * scale).clamp(11, 17);
  double get spacingS => (5 * scale).clamp(4, 10);
  double get spacingM => (11 * scale).clamp(9, 20);
  double get spacingL => (15 * scale).clamp(11, 26);
  double get spacingXL => (25 * scale).clamp(18, 42);
  double get bottomPadding => (25 * scale).clamp(18, 46);
  double get topPadding => (38 * scale).clamp(26, 68);
}
