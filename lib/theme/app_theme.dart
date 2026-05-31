import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bitly/models/theme_settings.dart';

/// Bitly/Flox Identity Theme with Glassmorphism
/// Cyber audio app with streaming FLAC premium aesthetic
/// NEON DESIGN: Light mode with dark green, Dark mode with light green
class AppTheme {
  // ============================================================================
  // NEON COLOR SCHEME - Light Mode (Dark Green Accents)
  // ============================================================================
  
  // Background Colors - Light Mode
  static const Color bgPrimaryLight = Color(0xFFF0F8FF); // Ice blue base
  static const Color bgSecondaryLight = Color(0xFFE6F7FF); // Lighter blue
  static const Color surfaceLight = Color(0xFFDEFCFF); // Surface with blue tint
  static const Color borderLight = Color(0xFFB3E5FC); // Light blue border
  
  // Primary Colors - Light Mode (DARK GREEN NEON)
  static const Color primaryLight = Color(0xFF006400); // Dark green primary
  static const Color primaryHoverLight = Color(0xFF004D00); // Darker green hover
  static const Color primaryActiveLight = Color(0xFF003300); // Deep green active
  static const Color glowLight = Color(0xFF00FF88); // Bright neon green glow
  
  // ============================================================================
  // NEON COLOR SCHEME - Dark Mode (Light Green Accents)
  // ============================================================================
  
  // Background Colors - Dark Mode
  static const Color bgPrimaryDark = Color(0xFF0A0E27); // Deep navy blue
  static const Color bgSecondaryDark = Color(0xFF0D1435); // Darker navy
  static const Color surfaceDark = Color(0xFF101A40); // Surface navy
  static const Color borderDark = Color(0xFF1A2A50); // Blue border
  
  // Primary Colors - Dark Mode (LIGHT GREEN NEON)
  static const Color primaryDark = Color(0xFF00FF88); // Bright neon green primary
  static const Color primaryHoverDark = Color(0xFF40FFA0); // Brighter green hover
  static const Color primaryActiveDark = Color(0xFF80FFA0); // Lighter green active
  static const Color glowDark = Color(0xFFA0FFC0); // Soft green glow
  
  // ============================================================================
  // Typography
  // ============================================================================
  
  static const Color textPrimaryDark = Color(0xFFE0F7FF); // Soft cyan white
  static const Color textSecondaryDark = Color(0xFFA0C4E0); // Muted cyan
  static const Color textMutedDark = Color(0xFF6A99B5); // Dark cyan
  
  static const Color textPrimaryLight = Color(0xFF001A0D); // Deep green-black text
  static const Color textSecondaryLight = Color(0xFF406A50); // Muted green text
  static const Color textMutedLight = Color(0xFF80A080); // Soft green-gray
  
  // ============================================================================
  // States
  // ============================================================================
  
  static const Color successDark = Color(0xFF00FF88);
  static const Color warningDark = Color(0xFFFFB84D);
  static const Color errorDark = Color(0xFFFF5C72);
  static const Color infoDark = Color(0xFF52C7FF);
  
  static const Color successLight = Color(0xFF006400);
  static const Color warningLight = Color(0xFFD98B1F);
  static const Color errorLight = Color(0xFFD9485F);
  static const Color infoLight = Color(0xFF238FD1);
  
  // ============================================================================
  // FUTURISTIC GLASSMORPHISM GRADIENTS
  // ============================================================================
  
  // Light Mode Gradient - Cyber Glass
  static LinearGradient gradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xB0F0F8FF), // Semi-transparent ice blue
      Color(0xA0E6F7FF), // Semi-transparent lighter blue
      Color(0x90DEFCFF), // Semi-transparent surface blue
    ],
    stops: const [0.0, 0.5, 1.0],
  );
  
  // Dark Mode Gradient - Cyber Glass
  static LinearGradient gradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xB00A0E27), // Semi-transparent deep navy
      Color(0xA00D1435), // Semi-transparent darker navy
      Color(0x90101A40), // Semi-transparent surface navy
    ],
    stops: const [0.0, 0.5, 1.0],
  );
  
  // Modal Background Gradient - Light
  static LinearGradient modalGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xC0F0F8FF), // More opaque ice blue
      Color(0xB0E6F7FF), // More opaque lighter blue
    ],
  );
  
  // Modal Background Gradient - Dark
  static LinearGradient modalGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xC00A0E27), // More opaque deep navy
      Color(0xB00D1435), // More opaque darker navy
    ],
  );
  
  // ============================================================================
  // GLASSMORPHISM EFFECTS
  // ============================================================================
  
  static const double glassBlurSigma = 40.0;
  static const double glassOpacity = 0.25;
  static const double modalGlassOpacity = 0.15;
  static const Color glassBorderDark = Color(0x4000FF88); // Neon green border glow
  static const Color glassBorderLight = Color(0x40006400); // Dark green border
  
  // Modal specific glass settings
  static const double modalBlurSigma = 30.0;
  static const Color modalBorderDark = Color(0x6000FF88); // Stronger neon border
  static const Color modalBorderLight = Color(0x60006400); // Stronger dark green border
  
  // ============================================================================
  // FUTURISTIC EFFECTS
  // ============================================================================
  
  // Box shadows for futuristic 3D effect
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
  
  // Inner glow for cards
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
  
  // ============================================================================
  // THEME GENERATORS
  // ============================================================================

  static ThemeData light({ColorScheme? dynamicScheme, Color? seedColor}) {
    final scheme =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: seedColor ?? primaryLight,
          brightness: Brightness.light,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: primaryLight,
        secondary: primaryHoverLight,
        tertiary: primaryActiveLight,
        surface: surfaceLight,
        background: bgPrimaryLight,
        surfaceContainer: bgSecondaryLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onBackground: textPrimaryLight,
        outline: borderLight,
        primaryContainer: primaryLight.withOpacity(0.2),
        secondaryContainer: primaryHoverLight.withOpacity(0.2),
        surfaceContainerHighest: surfaceLight.withOpacity(0.3),
        surfaceContainerLow: surfaceLight.withOpacity(0.15),
      ),
      scaffoldBackgroundColor: bgPrimaryLight,
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
      dividerColor: borderLight.withOpacity(0.3),
      canvasColor: bgPrimaryLight,
      
      // Custom properties for glassmorphism
      extensions: const [
        _GlassThemeExtensions(
          blurSigma: glassBlurSigma,
          glassOpacity: glassOpacity,
          borderColor: glassBorderLight,
        ),
      ],
    );
  }

  static ThemeData dark({
    ColorScheme? dynamicScheme,
    Color? seedColor,
    bool isAmoled = false,
  }) {
    final scheme =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: seedColor ?? primaryDark,
          brightness: Brightness.dark,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: primaryDark,
        secondary: primaryHoverDark,
        tertiary: primaryActiveDark,
        surface: surfaceDark,
        background: bgPrimaryDark,
        surfaceContainer: bgSecondaryDark,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimaryDark,
        onBackground: textPrimaryDark,
        outline: borderDark,
        primaryContainer: primaryDark.withOpacity(0.2),
        secondaryContainer: primaryHoverDark.withOpacity(0.2),
        surfaceContainerHighest: surfaceDark.withOpacity(0.3),
        surfaceContainerLow: surfaceDark.withOpacity(0.15),
      ),
      scaffoldBackgroundColor: isAmoled ? Colors.black : bgPrimaryDark,
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
      dividerColor: borderDark.withOpacity(0.3),
      canvasColor: isAmoled ? Colors.black : bgPrimaryDark,
      
      // Custom properties for glassmorphism
      extensions: const [
        _GlassThemeExtensions(
          blurSigma: glassBlurSigma,
          glassOpacity: glassOpacity,
          borderColor: glassBorderDark,
        ),
      ],
    );
  }

  static AppBarTheme _appBarTheme(
    ColorScheme scheme, {
    bool isAmoled = false,
    bool isDark = false,
  }) => AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: isAmoled ? 0 : 3,
    backgroundColor: isAmoled 
        ? Colors.black 
        : (isDark ? surfaceDark.withOpacity(0.8) : surfaceLight.withOpacity(0.8)),
    foregroundColor: scheme.onSurface,
    surfaceTintColor: isAmoled ? Colors.transparent : scheme.surfaceTint,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: scheme.onSurface,
      fontSize: 22,
      fontWeight: FontWeight.w500,
      shadows: [
        Shadow(
          color: isDark ? primaryDark.withOpacity(0.3) : primaryLight.withOpacity(0.2),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: scheme.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: isAmoled
          ? Colors.black
          : scheme.surfaceContainer,
      systemNavigationBarIconBrightness: scheme.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    ),
  );

  static CardThemeData _cardTheme(ColorScheme scheme, {required bool isDark}) => CardThemeData(
    elevation: 0,
    shadowColor: isDark ? primaryDark.withOpacity(0.2) : primaryLight.withOpacity(0.2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    color: isDark 
        ? surfaceDark.withOpacity(0.4) 
        : surfaceLight.withOpacity(0.4),
    surfaceTintColor: isDark ? glowDark : glowLight,
    margin: const EdgeInsets.all(4),
  );

  static ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme scheme) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shadowColor: scheme.primary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          animationDuration: const Duration(milliseconds: 300),
          enableFeedback: true,
        ),
      );

  static FilledButtonThemeData _filledButtonTheme(ColorScheme scheme) =>
      FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          animationDuration: const Duration(milliseconds: 300),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme scheme) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: BorderSide(color: scheme.outline, width: 1.5),
          animationDuration: const Duration(milliseconds: 300),
        ),
      );

  static TextButtonThemeData _textButtonTheme(ColorScheme scheme) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          animationDuration: const Duration(milliseconds: 200),
        ),
      );

  static FloatingActionButtonThemeData _fabTheme(ColorScheme scheme) =>
      FloatingActionButtonThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      );

  static InputDecorationTheme _inputDecorationTheme(ColorScheme scheme, {required bool isDark}) =>
      InputDecorationTheme(
        filled: true,
        fillColor: isDark 
            ? scheme.surfaceContainerHighest.withOpacity(0.4) 
            : scheme.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: isDark ? glassBorderDark : glassBorderLight,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: isDark ? glowDark : glowLight,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: isDark ? errorDark : errorLight,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withOpacity(0.7),
        ),
      );

  static ListTileThemeData _listTileTheme(ColorScheme scheme) =>
      ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 48,
      );

  static DialogThemeData _dialogTheme(ColorScheme scheme, {required bool isDark}) => DialogThemeData(
    elevation: 0,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shadowColor: isDark ? primaryDark.withOpacity(0.3) : primaryLight.withOpacity(0.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  );

  static NavigationBarThemeData _navigationBarTheme(
    ColorScheme scheme, {
    bool isAmoled = false,
    bool isDark = false,
  }) => NavigationBarThemeData(
    elevation: 0,
    backgroundColor: isAmoled 
        ? Colors.black 
        : (isDark ? surfaceDark.withOpacity(0.9) : surfaceLight.withOpacity(0.9)),
    indicatorColor: isDark ? primaryDark.withOpacity(0.3) : primaryLight.withOpacity(0.3),
    surfaceTintColor: isAmoled ? Colors.transparent : scheme.surfaceTint,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    height: 72,
  );

  static SnackBarThemeData _snackBarTheme(ColorScheme scheme) =>
      SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: scheme.inverseSurface.withOpacity(0.95),
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        elevation: 6,
        actionTextColor: scheme.primary,
      );

  static ProgressIndicatorThemeData _progressIndicatorTheme(
    ColorScheme scheme,
  ) => ProgressIndicatorThemeData(
    color: scheme.primary,
    linearTrackColor: scheme.surfaceContainerHighest,
    circularTrackColor: scheme.surfaceContainerHighest,
  );

  static SwitchThemeData _switchTheme(ColorScheme scheme) => SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return scheme.onPrimary;
      }
      return scheme.outline;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return scheme.primary;
      }
      return scheme.surfaceContainerHighest;
    }),
    thumbIcon: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return Icon(Icons.check, color: scheme.primary, size: 16);
      }
      return null;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return scheme.primary.withOpacity(0.2);
      }
      return Colors.transparent;
    }),
  );

  static ChipThemeData _chipTheme(ColorScheme scheme) => ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: scheme.surfaceContainerLow,
    selectedColor: scheme.secondaryContainer,
    secondarySelectedColor: scheme.tertiaryContainer,
    labelStyle: TextStyle(color: scheme.onSurfaceVariant),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    side: BorderSide.none,
    brightness: scheme.brightness,
  );

  static DividerThemeData _dividerTheme(ColorScheme scheme) =>
      DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
        indent: 0,
        endIndent: 0,
      );
}

// ============================================================================
// CUSTOM THEME EXTENSIONS FOR GLASSMORPHISM
// ============================================================================

class _GlassThemeExtensions extends ThemeExtension<_GlassThemeExtensions> {
  final double blurSigma;
  final double glassOpacity;
  final Color borderColor;
  
  const _GlassThemeExtensions({
    required this.blurSigma,
    required this.glassOpacity,
    required this.borderColor,
  });
  
  @override
  ThemeExtension<_GlassThemeExtensions> copyWith({
    double? blurSigma,
    double? glassOpacity,
    Color? borderColor,
  }) {
    return _GlassThemeExtensions(
      blurSigma: blurSigma ?? this.blurSigma,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      borderColor: borderColor ?? this.borderColor,
    );
  }
  
  @override
  ThemeExtension<_GlassThemeExtensions> lerp(
    ThemeExtension<_GlassThemeExtensions>? other,
    double t,
  ) {
    if (other is! _GlassThemeExtensions) {
      return this;
    }
    return _GlassThemeExtensions(
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t) ?? blurSigma,
      glassOpacity: lerpDouble(glassOpacity, other.glassOpacity, t) ?? glassOpacity,
      borderColor: Color.lerp(borderColor, other.borderColor, t) ?? borderColor,
    );
  }
}

// Extension method to access glass theme properties
extension GlassThemeExt on ThemeData {
  _GlassThemeExtensions get glassExtensions {
    final allExtensions = extensions;
    if (allExtensions != null) {
      for (final ext in allExtensions.values) {
        if (ext is _GlassThemeExtensions) return ext;
      }
    }
    return const _GlassThemeExtensions(
      blurSigma: AppTheme.glassBlurSigma,
      glassOpacity: AppTheme.glassOpacity,
      borderColor: AppTheme.glassBorderLight,
    );
  }
}
