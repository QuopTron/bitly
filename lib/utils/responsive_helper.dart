import 'package:flutter/material.dart';

/// Responsive utility functions to prevent overflows and create beautiful layouts
class ResponsiveHelper {
  /// Get screen size categories
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return ScreenSize.phone;
    if (width < 900) return ScreenSize.tablet;
    if (width < 1200) return ScreenSize.desktop;
    return ScreenSize.largeDesktop;
  }

  /// Calculate responsive grid column count
  static int getGridColumnCount(BuildContext context, {
    int phone = 2,
    int tablet = 3,
    int desktop = 4,
    int largeDesktop = 5,
  }) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.phone:
        return phone;
      case ScreenSize.tablet:
        return tablet;
      case ScreenSize.desktop:
        return desktop;
      case ScreenSize.largeDesktop:
        return largeDesktop;
    }
  }

  /// Calculate responsive spacing
  static double getSpacing(BuildContext context, {
    double phone = 8,
    double tablet = 12,
    double desktop = 16,
    double largeDesktop = 24,
  }) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.phone:
        return phone;
      case ScreenSize.tablet:
        return tablet;
      case ScreenSize.desktop:
        return desktop;
      case ScreenSize.largeDesktop:
        return largeDesktop;
    }
  }

  /// Calculate responsive padding
  static double getPadding(BuildContext context, {
    double phone = 12,
    double tablet = 16,
    double desktop = 24,
    double largeDesktop = 32,
  }) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.phone:
        return phone;
      case ScreenSize.tablet:
        return tablet;
      case ScreenSize.desktop:
        return desktop;
      case ScreenSize.largeDesktop:
        return largeDesktop;
    }
  }

  /// Calculate responsive font size
  static double getFontSize(BuildContext context, {
    double phone = 14,
    double tablet = 15,
    double desktop = 16,
    double largeDesktop = 18,
  }) {
    final size = getScreenSize(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3);
    
    double baseFontSize;
    switch (size) {
      case ScreenSize.phone:
        baseFontSize = phone;
        break;
      case ScreenSize.tablet:
        baseFontSize = tablet;
        break;
      case ScreenSize.desktop:
        baseFontSize = desktop;
        break;
      case ScreenSize.largeDesktop:
        baseFontSize = largeDesktop;
        break;
    }
    
    return baseFontSize * textScale;
  }

  /// Calculate responsive card size
  static double getCardSize(BuildContext context, {
    double phone = 160,
    double tablet = 180,
    double desktop = 200,
    double largeDesktop = 240,
  }) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.phone:
        return phone;
      case ScreenSize.tablet:
        return tablet;
      case ScreenSize.desktop:
        return desktop;
      case ScreenSize.largeDesktop:
        return largeDesktop;
    }
  }

  /// Get max content width to prevent stretching on large screens
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = getScreenSize(context);
    
    switch (size) {
      case ScreenSize.phone:
        return width;
      case ScreenSize.tablet:
        return width * 0.9;
      case ScreenSize.desktop:
        return 1200.0;
      case ScreenSize.largeDesktop:
        return 1400.0;
    }
  }

  /// Create responsive cross axis count for GridView
  static SliverGridDelegate getGridDelegate(BuildContext context, {
    double phoneCrossAxisCount = 2,
    double tabletCrossAxisCount = 3,
    double desktopCrossAxisCount = 4,
    double largeDesktopCrossAxisCount = 5,
    double childAspectRatio = 0.75,
    double mainAxisSpacing = 8,
    double crossAxisSpacing = 8,
  }) {
    final count = getGridColumnCount(
      context,
      phone: phoneCrossAxisCount.toInt(),
      tablet: tabletCrossAxisCount.toInt(),
      desktop: desktopCrossAxisCount.toInt(),
      largeDesktop: largeDesktopCrossAxisCount.toInt(),
    );

    final spacing = getSpacing(context);

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: count,
      childAspectRatio: childAspectRatio,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
    );
  }

  /// Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape;
  }

  /// Get adaptive layout (mobile vs desktop)
  static bool isDesktop(BuildContext context) {
    final size = getScreenSize(context);
    return size == ScreenSize.desktop || size == ScreenSize.largeDesktop;
  }

  /// Calculate responsive height for containers
  static double getHeight(BuildContext context, {
    required double phone,
    required double tablet,
    required double desktop,
    double? largeDesktop,
  }) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.phone:
        return phone;
      case ScreenSize.tablet:
        return tablet;
      case ScreenSize.desktop:
        return desktop;
      case ScreenSize.largeDesktop:
        return largeDesktop ?? desktop;
    }
  }
}

/// Screen size categories
enum ScreenSize {
  phone,      // < 600px
  tablet,     // 600-900px
  desktop,    // 900-1200px
  largeDesktop, // > 1200px
}

/// Responsive text widget that adapts to screen size
class ResponsiveText extends StatelessWidget {
  final String text;
  final double phoneSize;
  final double tabletSize;
  final double desktopSize;
  final double largeDesktopSize;
  final FontWeight fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    required this.phoneSize,
    this.tabletSize = 15,
    this.desktopSize = 16,
    this.largeDesktopSize = 18,
    this.fontWeight = FontWeight.normal,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = ResponsiveHelper.getFontSize(
      context,
      phone: phoneSize,
      tablet: tabletSize,
      desktop: desktopSize,
      largeDesktop: largeDesktopSize,
    );

    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
    );
  }
}

/// Responsive container that prevents overflows
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? EdgeInsets.all(ResponsiveHelper.getPadding(context));
    final effectiveMaxWidth = maxWidth ?? ResponsiveHelper.getMaxContentWidth(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}
