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

  double val(double ideal, double min, double max) => (ideal * scale).clamp(min, max);

  double get logoSize => val(90, 56, 150);
  double get circlePadding => val(18, 10, 30);
  double get titleSize => val(18, 14, 26);
  double get subtitleSize => val(12, 10, 16);
  double get footerSize => val(10, 9, 13);
  double get retryButtonHeight => val(36, 28, 44);
  double get continueButtonHeight => val(38, 32, 48);
  double get languageCardVPadding => val(12, 9, 20);
  double get languageCardHPadding => val(16, 11, 26);
  double get languageCardMargin => val(22, 14, 40);
  double get languageCardIconSize => val(28, 22, 38);
  double get languageCheckSize => val(11, 9, 14);
  double get spacingXS => val(4, 3, 6);
  double get spacingS => val(6, 4, 8);
  double get spacingM => val(10, 8, 16);
  double get spacingL => val(14, 10, 22);
  double get spacingXL => val(20, 16, 32);
  double get bottomPadding => val(20, 14, 34);
  double get topPadding => val(30, 20, 52);
}
