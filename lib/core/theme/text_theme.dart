import 'package:flutter/material.dart';
import 'color_scheme.dart';

class AppTextTheme {
  AppTextTheme._();

  static const String _fontFamily = 'Inter';

  static final TextTheme darkTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: AppColors.onBackground,
      letterSpacing: -1.5,
    ),
    displayMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: AppColors.onBackground,
      letterSpacing: -0.5,
    ),
    displaySmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: AppColors.onBackground,
    ),
    headlineLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.onBackground,
    ),
    headlineMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.onBackground,
    ),
    headlineSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.onBackground,
    ),
    titleLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.onBackground,
    ),
    titleMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.onBackground,
    ),
    titleSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.onSurface,
    ),
    bodyLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: AppColors.onBackground,
    ),
    bodyMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: AppColors.onSurface,
    ),
    bodySmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: AppColors.onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.onBackground,
      letterSpacing: 0.5,
    ),
    labelMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.onSurface,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.onSurfaceVariant,
      letterSpacing: 0.5,
    ),
  );
}
