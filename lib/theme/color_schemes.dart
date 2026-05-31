import 'package:flutter/material.dart';

class AppColors {
  static const Color bgPrimaryLight = Color(0xFFF0F8FF);
  static const Color bgSecondaryLight = Color(0xFFE6F7FF);
  static const Color surfaceLight = Color(0xFFDEFCFF);
  static const Color borderLight = Color(0xFFB3E5FC);

  static const Color primaryLight = Color(0xFF006400);
  static const Color primaryHoverLight = Color(0xFF004D00);
  static const Color primaryActiveLight = Color(0xFF003300);
  static const Color glowLight = Color(0xFF00FF88);

  static const Color bgPrimaryDark = Color(0xFF0A0E27);
  static const Color bgSecondaryDark = Color(0xFF0D1435);
  static const Color surfaceDark = Color(0xFF101A40);
  static const Color borderDark = Color(0xFF1A2A50);

  static const Color primaryDark = Color(0xFF00FF88);
  static const Color primaryHoverDark = Color(0xFF40FFA0);
  static const Color primaryActiveDark = Color(0xFF80FFA0);
  static const Color glowDark = Color(0xFFA0FFC0);

  static const Color successDark = Color(0xFF00FF88);
  static const Color warningDark = Color(0xFFFFB84D);
  static const Color errorDark = Color(0xFFFF5C72);
  static const Color infoDark = Color(0xFF52C7FF);

  static const Color successLight = Color(0xFF006400);
  static const Color warningLight = Color(0xFFD98B1F);
  static const Color errorLight = Color(0xFFD9485F);
  static const Color infoLight = Color(0xFF238FD1);

  static const Color glassBorderDark = Color(0x4000FF88);
  static const Color glassBorderLight = Color(0x40006400);
  static const Color modalBorderDark = Color(0x6000FF88);
  static const Color modalBorderLight = Color(0x60006400);

  static const double glassBlurSigma = 40.0;
  static const double glassOpacity = 0.25;
  static const double modalGlassOpacity = 0.15;
  static const double modalBlurSigma = 30.0;

  static LinearGradient gradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xB0F0F8FF),
      Color(0xA0E6F7FF),
      Color(0x90DEFCFF),
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  static LinearGradient gradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xB00A0E27),
      Color(0xA00D1435),
      Color(0x90101A40),
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  static LinearGradient modalGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xC0F0F8FF),
      Color(0xB0E6F7FF),
    ],
  );

  static LinearGradient modalGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xC00A0E27),
      Color(0xB00D1435),
    ],
  );

  static BoxShadow futuristicShadowDark = BoxShadow(
    color: Color(0x4000FF88),
    blurRadius: 30,
    spreadRadius: 2,
    offset: const Offset(0, 8),
  );

  static BoxShadow futuristicShadowLight = BoxShadow(
    color: Color(0x40006400),
    blurRadius: 30,
    spreadRadius: 2,
    offset: const Offset(0, 8),
  );

  static BoxDecoration cardGlowDecoration({required bool isDark, double borderRadius = 16}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: isDark ? Color(0x6000FF88) : Color(0x60006400),
          blurRadius: 20,
          spreadRadius: 1,
          offset: const Offset(0, 0),
        ),
      ],
    );
  }
}