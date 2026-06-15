import 'package:flutter/material.dart';
import '../color_scheme.dart';

extension ThemeExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get primaryColor => AppColors.primary;
  Color get backgroundColor => AppColors.background;
  Color get surfaceColor => AppColors.surface;
  Color get onSurfaceColor => AppColors.onSurface;
}
