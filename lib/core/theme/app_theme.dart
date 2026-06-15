import 'package:flutter/material.dart';
import 'color_scheme.dart';
import 'text_theme.dart';
import 'component_themes/button_theme.dart';
import 'component_themes/card_theme.dart';
import 'component_themes/input_theme.dart';
import 'component_themes/app_bar_theme.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: AppColors.darkScheme,
      scaffoldBackgroundColor: AppColors.background,

      textTheme: AppTextTheme.darkTextTheme,
      primaryTextTheme: AppTextTheme.darkTextTheme,

      elevatedButtonTheme: AppButtonTheme.darkElevatedButtonTheme,
      outlinedButtonTheme: AppButtonTheme.darkOutlinedButtonTheme,
      textButtonTheme: AppButtonTheme.darkTextButtonTheme,

      cardTheme: AppCardTheme.darkCardTheme,

      inputDecorationTheme: AppInputTheme.darkInputDecorationTheme,

      appBarTheme: CustomAppBarTheme.darkAppBarTheme,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
        thickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: AppTextTheme.darkTextTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
