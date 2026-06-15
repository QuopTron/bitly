import 'package:flutter/material.dart';
import '../color_scheme.dart';
import '../../constants/theme_constants.dart';

class AppInputTheme {
  AppInputTheme._();

  static final darkInputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceHigh,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
    hintStyle: TextStyle(
      color: AppColors.onSurfaceVariant,
      fontSize: 14,
    ),
    labelStyle: TextStyle(
      color: AppColors.onSurface,
      fontSize: 14,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ThemeConstants.radiusSm),
      borderSide: BorderSide(color: AppColors.onSurfaceVariant, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ThemeConstants.radiusSm),
      borderSide: BorderSide(
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
        width: 1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ThemeConstants.radiusSm),
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ThemeConstants.radiusSm),
      borderSide: BorderSide(color: AppColors.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ThemeConstants.radiusSm),
      borderSide: BorderSide(color: AppColors.error, width: 2),
    ),
    errorStyle: TextStyle(
      color: AppColors.error,
      fontSize: 12,
    ),
  );
}
