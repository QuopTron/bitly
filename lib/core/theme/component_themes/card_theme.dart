import 'package:flutter/material.dart';
import '../color_scheme.dart';
import '../../constants/theme_constants.dart';

class AppCardTheme {
  AppCardTheme._();

  static final darkCardTheme = CardThemeData(
    color: AppColors.glassBackground,
    elevation: 0,
    shadowColor: AppColors.neonGlow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ThemeConstants.radiusMd),
      side: BorderSide(
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
        width: 0.5,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    surfaceTintColor: Colors.transparent,
    margin: EdgeInsets.zero,
  );

  static BoxDecoration glassDecoration = BoxDecoration(
    color: AppColors.glassBackground,
    borderRadius: BorderRadius.circular(ThemeConstants.radiusMd),
    border: Border.all(
      color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
      width: 0.5,
    ),
  );
}
