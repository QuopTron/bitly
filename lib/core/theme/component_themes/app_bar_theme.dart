import 'package:flutter/material.dart';
import '../color_scheme.dart';

class CustomAppBarTheme {
  CustomAppBarTheme._();

  static const darkAppBarTheme = AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.onBackground,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.onBackground,
    ),
    iconTheme: IconThemeData(
      color: AppColors.onBackground,
      size: 24,
    ),
    actionsIconTheme: IconThemeData(
      color: AppColors.onBackground,
      size: 24,
    ),
  );
}
