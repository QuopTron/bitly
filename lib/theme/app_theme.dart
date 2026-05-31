import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bitly/theme/theme_settings.dart';

import 'color_schemes.dart';
import 'text_styles.dart';

export 'color_schemes.dart';
export 'text_styles.dart';

class AppTheme {
  static const Color bgPrimaryLight = AppColors.bgPrimaryLight;
  static const Color bgSecondaryLight = AppColors.bgSecondaryLight;
  static const Color surfaceLight = AppColors.surfaceLight;
  static const Color borderLight = AppColors.borderLight;

  static const Color primaryLight = AppColors.primaryLight;
  static const Color primaryHoverLight = AppColors.primaryHoverLight;
  static const Color primaryActiveLight = AppColors.primaryActiveLight;
  static const Color glowLight = AppColors.glowLight;

  static const Color bgPrimaryDark = AppColors.bgPrimaryDark;
  static const Color bgSecondaryDark = AppColors.bgSecondaryDark;
  static const Color surfaceDark = AppColors.surfaceDark;
  static const Color borderDark = AppColors.borderDark;

  static const Color primaryDark = AppColors.primaryDark;
  static const Color primaryHoverDark = AppColors.primaryHoverDark;
  static const Color primaryActiveDark = AppColors.primaryActiveDark;
  static const Color glowDark = AppColors.glowDark;

  static const Color textPrimaryDark = AppTextStyles.textPrimaryDark;
  static const Color textSecondaryDark = AppTextStyles.textSecondaryDark;
  static const Color textMutedDark = AppTextStyles.textMutedDark;

  static const Color textPrimaryLight = AppTextStyles.textPrimaryLight;
  static const Color textSecondaryLight = AppTextStyles.textSecondaryLight;
  static const Color textMutedLight = AppTextStyles.textMutedLight;

  static const Color successDark = AppColors.successDark;
  static const Color warningDark = AppColors.warningDark;
  static const Color errorDark = AppColors.errorDark;
  static const Color infoDark = AppColors.infoDark;

  static const Color successLight = AppColors.successLight;
  static const Color warningLight = AppColors.warningLight;
  static const Color errorLight = AppColors.errorLight;
  static const Color infoLight = AppColors.infoLight;

  static const double glassBlurSigma = AppColors.glassBlurSigma;
  static const double glassOpacity = AppColors.glassOpacity;
  static const double modalGlassOpacity = AppColors.modalGlassOpacity;
  static const double modalBlurSigma = AppColors.modalBlurSigma;
  static const Color glassBorderDark = AppColors.glassBorderDark;
  static const Color glassBorderLight = AppColors.glassBorderLight;
  static const Color modalBorderDark = AppColors.modalBorderDark;
  static const Color modalBorderLight = AppColors.modalBorderLight;

  static LinearGradient get gradientLight => AppColors.gradientLight;
  static LinearGradient get gradientDark => AppColors.gradientDark;
  static LinearGradient get modalGradientLight => AppColors.modalGradientLight;
  static LinearGradient get modalGradientDark => AppColors.modalGradientDark;
  static BoxShadow get futuristicShadowDark => AppColors.futuristicShadowDark;
  static BoxShadow get futuristicShadowLight => AppColors.futuristicShadowLight;
  static BoxDecoration cardGlowDecoration({required bool isDark, double borderRadius = 16}) =>
      AppColors.cardGlowDecoration(isDark: isDark, borderRadius: borderRadius);
}

ThemeData lightTheme({ColorScheme? dynamicScheme, Color? seedColor}) {
  final scheme = dynamicScheme ?? ColorScheme.fromSeed(seedColor: seedColor ?? AppColors.primaryLight, brightness: Brightness.light);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: AppColors.primaryLight,
      secondary: AppColors.primaryHoverLight,
      tertiary: AppColors.primaryActiveLight,
      surface: AppColors.surfaceLight,
      background: AppColors.bgPrimaryLight,
      surfaceContainer: AppColors.bgSecondaryLight,
      onPrimary: Colors.white, onSecondary: Colors.white,
      onSurface: AppTextStyles.textPrimaryLight,
      onBackground: AppTextStyles.textPrimaryLight,
      outline: AppColors.borderLight,
      primaryContainer: AppColors.primaryLight.withOpacity(0.2),
      secondaryContainer: AppColors.primaryHoverLight.withOpacity(0.2),
      surfaceContainerHighest: AppColors.surfaceLight.withOpacity(0.3),
      surfaceContainerLow: AppColors.surfaceLight.withOpacity(0.15),
    ),
    scaffoldBackgroundColor: AppColors.bgPrimaryLight,
    appBarTheme: _appBarTheme(scheme, isDark: false),
    cardTheme: _cardTheme(scheme, isDark: false),
    elevatedButtonTheme: _elevatedButtonTheme(scheme),
    filledButtonTheme: _filledButtonTheme(scheme),
    outlinedButtonTheme: _outlinedButtonTheme(scheme),
    textButtonTheme: _textButtonTheme(scheme),
    floatingActionButtonTheme: _fabTheme(scheme),
    inputDecorationTheme: _inputDecorationTheme(scheme, isDark: false),
    listTileTheme: _listTileTheme(scheme),
    dialogTheme: _dialogTheme(scheme, isDark: false),
    navigationBarTheme: _navigationBarTheme(scheme, isDark: false),
    snackBarTheme: _snackBarTheme(scheme),
    progressIndicatorTheme: _progressIndicatorTheme(scheme),
    switchTheme: _switchTheme(scheme),
    chipTheme: _chipTheme(scheme),
    dividerTheme: _dividerTheme(scheme),
    fontFamily: 'Google Sans Flex',
    dividerColor: AppColors.borderLight.withOpacity(0.3),
    canvasColor: AppColors.bgPrimaryLight,
    extensions: const [_GlassThemeExtensions(blurSigma: AppColors.glassBlurSigma, glassOpacity: AppColors.glassOpacity, borderColor: AppColors.glassBorderLight)],
  );
}

ThemeData darkTheme({ColorScheme? dynamicScheme, Color? seedColor, bool isAmoled = false}) {
  final scheme = dynamicScheme ?? ColorScheme.fromSeed(seedColor: seedColor ?? AppColors.primaryDark, brightness: Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: AppColors.primaryDark,
      secondary: AppColors.primaryHoverDark,
      tertiary: AppColors.primaryActiveDark,
      surface: AppColors.surfaceDark,
      background: AppColors.bgPrimaryDark,
      surfaceContainer: AppColors.bgSecondaryDark,
      onPrimary: Colors.black, onSecondary: Colors.black,
      onSurface: AppTextStyles.textPrimaryDark,
      onBackground: AppTextStyles.textPrimaryDark,
      outline: AppColors.borderDark,
      primaryContainer: AppColors.primaryDark.withOpacity(0.2),
      secondaryContainer: AppColors.primaryHoverDark.withOpacity(0.2),
      surfaceContainerHighest: AppColors.surfaceDark.withOpacity(0.3),
      surfaceContainerLow: AppColors.surfaceDark.withOpacity(0.15),
    ),
    scaffoldBackgroundColor: isAmoled ? Colors.black : AppColors.bgPrimaryDark,
    appBarTheme: _appBarTheme(scheme, isAmoled: isAmoled, isDark: true),
    cardTheme: _cardTheme(scheme, isDark: true),
    elevatedButtonTheme: _elevatedButtonTheme(scheme),
    filledButtonTheme: _filledButtonTheme(scheme),
    outlinedButtonTheme: _outlinedButtonTheme(scheme),
    textButtonTheme: _textButtonTheme(scheme),
    floatingActionButtonTheme: _fabTheme(scheme),
    inputDecorationTheme: _inputDecorationTheme(scheme, isDark: true),
    listTileTheme: _listTileTheme(scheme),
    dialogTheme: _dialogTheme(scheme, isDark: true),
    navigationBarTheme: _navigationBarTheme(scheme, isAmoled: isAmoled, isDark: true),
    snackBarTheme: _snackBarTheme(scheme),
    progressIndicatorTheme: _progressIndicatorTheme(scheme),
    switchTheme: _switchTheme(scheme),
    chipTheme: _chipTheme(scheme),
    dividerTheme: _dividerTheme(scheme),
    fontFamily: 'Google Sans Flex',
    dividerColor: AppColors.borderDark.withOpacity(0.3),
    canvasColor: isAmoled ? Colors.black : AppColors.bgPrimaryDark,
    extensions: const [_GlassThemeExtensions(blurSigma: AppColors.glassBlurSigma, glassOpacity: AppColors.glassOpacity, borderColor: AppColors.glassBorderDark)],
  );
}

AppBarTheme _appBarTheme(ColorScheme scheme, {bool isAmoled = false, bool isDark = false}) => AppBarTheme(
  elevation: 0,
  scrolledUnderElevation: isAmoled ? 0 : 3,
  backgroundColor: isAmoled ? Colors.black : (isDark ? AppColors.surfaceDark.withOpacity(0.8) : AppColors.surfaceLight.withOpacity(0.8)),
  foregroundColor: scheme.onSurface,
  surfaceTintColor: isAmoled ? Colors.transparent : scheme.surfaceTint,
  centerTitle: true,
  titleTextStyle: TextStyle(
    color: scheme.onSurface,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    shadows: [Shadow(color: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primaryLight.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 2))],
  ),
  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: scheme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: isAmoled ? Colors.black : scheme.surfaceContainer,
    systemNavigationBarIconBrightness: scheme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
  ),
);

CardThemeData _cardTheme(ColorScheme scheme, {required bool isDark}) => CardThemeData(
  elevation: 0,
  shadowColor: isDark ? AppColors.primaryDark.withOpacity(0.2) : AppColors.primaryLight.withOpacity(0.2),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  color: isDark ? AppColors.surfaceDark.withOpacity(0.4) : AppColors.surfaceLight.withOpacity(0.4),
  surfaceTintColor: isDark ? AppColors.glowDark : AppColors.glowLight,
  margin: const EdgeInsets.all(4),
);

ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme scheme) => ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    elevation: 2,
    shadowColor: scheme.primary.withOpacity(0.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    backgroundColor: scheme.primary,
    foregroundColor: scheme.onPrimary,
    animationDuration: const Duration(milliseconds: 300),
    enableFeedback: true,
  ),
);

FilledButtonThemeData _filledButtonTheme(ColorScheme scheme) => FilledButtonThemeData(
  style: FilledButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    animationDuration: const Duration(milliseconds: 300),
  ),
);

OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme scheme) => OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    side: BorderSide(color: scheme.outline, width: 1.5),
    animationDuration: const Duration(milliseconds: 300),
  ),
);

TextButtonThemeData _textButtonTheme(ColorScheme scheme) => TextButtonThemeData(
  style: TextButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    animationDuration: const Duration(milliseconds: 200),
  ),
);

FloatingActionButtonThemeData _fabTheme(ColorScheme scheme) => FloatingActionButtonThemeData(
  elevation: 3,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  backgroundColor: scheme.primaryContainer,
  foregroundColor: scheme.onPrimaryContainer,
  extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
);

InputDecorationTheme _inputDecorationTheme(ColorScheme scheme, {required bool isDark}) => InputDecorationTheme(
  filled: true,
  fillColor: scheme.surfaceContainerHighest.withOpacity(0.4),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight, width: 1.5)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? AppColors.glowDark : AppColors.glowLight, width: 2)),
  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? AppColors.errorDark : AppColors.errorLight, width: 1.5)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  hintStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.7)),
);

ListTileThemeData _listTileTheme(ColorScheme scheme) => ListTileThemeData(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  minLeadingWidth: 48,
);

DialogThemeData _dialogTheme(ColorScheme scheme, {required bool isDark}) => DialogThemeData(
  elevation: 0,
  backgroundColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  shadowColor: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primaryLight.withOpacity(0.3),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
);

NavigationBarThemeData _navigationBarTheme(ColorScheme scheme, {bool isAmoled = false, bool isDark = false}) => NavigationBarThemeData(
  elevation: 0,
  backgroundColor: isAmoled ? Colors.black : (isDark ? AppColors.surfaceDark.withOpacity(0.9) : AppColors.surfaceLight.withOpacity(0.9)),
  indicatorColor: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primaryLight.withOpacity(0.3),
  surfaceTintColor: isAmoled ? Colors.transparent : scheme.surfaceTint,
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  height: 72,
);

SnackBarThemeData _snackBarTheme(ColorScheme scheme) => SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  backgroundColor: scheme.inverseSurface.withOpacity(0.95),
  contentTextStyle: TextStyle(color: scheme.onInverseSurface),
  elevation: 6,
  actionTextColor: scheme.primary,
);

ProgressIndicatorThemeData _progressIndicatorTheme(ColorScheme scheme) => ProgressIndicatorThemeData(
  color: scheme.primary,
  linearTrackColor: scheme.surfaceContainerHighest,
  circularTrackColor: scheme.surfaceContainerHighest,
);

SwitchThemeData _switchTheme(ColorScheme scheme) => SwitchThemeData(
  thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline),
  trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest),
  thumbIcon: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Icon(Icons.check, color: scheme.primary, size: 16) : null),
  overlayColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.pressed) ? scheme.primary.withOpacity(0.2) : Colors.transparent),
);

ChipThemeData _chipTheme(ColorScheme scheme) => ChipThemeData(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  backgroundColor: scheme.surfaceContainerLow,
  selectedColor: scheme.secondaryContainer,
  secondarySelectedColor: scheme.tertiaryContainer,
  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  side: BorderSide.none,
  brightness: scheme.brightness,
);

DividerThemeData _dividerTheme(ColorScheme scheme) => DividerThemeData(
  color: scheme.outlineVariant, thickness: 1, space: 1, indent: 0, endIndent: 0,
);

class _GlassThemeExtensions extends ThemeExtension<_GlassThemeExtensions> {
  final double blurSigma;
  final double glassOpacity;
  final Color borderColor;

  const _GlassThemeExtensions({required this.blurSigma, required this.glassOpacity, required this.borderColor});

  @override
  ThemeExtension<_GlassThemeExtensions> copyWith({double? blurSigma, double? glassOpacity, Color? borderColor}) {
    return _GlassThemeExtensions(blurSigma: blurSigma ?? this.blurSigma, glassOpacity: glassOpacity ?? this.glassOpacity, borderColor: borderColor ?? this.borderColor);
  }

  @override
  ThemeExtension<_GlassThemeExtensions> lerp(ThemeExtension<_GlassThemeExtensions>? other, double t) {
    if (other is! _GlassThemeExtensions) return this;
    return _GlassThemeExtensions(
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t) ?? blurSigma,
      glassOpacity: lerpDouble(glassOpacity, other.glassOpacity, t) ?? glassOpacity,
      borderColor: Color.lerp(borderColor, other.borderColor, t) ?? borderColor,
    );
  }
}

extension GlassThemeExt on ThemeData {
  _GlassThemeExtensions get glassExtensions {
    final allExtensions = extensions;
    if (allExtensions != null) {
      for (final ext in allExtensions.values) {
        if (ext is _GlassThemeExtensions) return ext;
      }
    }
    return const _GlassThemeExtensions(blurSigma: AppColors.glassBlurSigma, glassOpacity: AppColors.glassOpacity, borderColor: AppColors.glassBorderLight);
  }
}